package executor

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type Chain struct {
	client *ethclient.Client
	key    *ecdsa.PrivateKey
	from   common.Address
	chainID *big.Int
}

func Dial(ctx context.Context, rpcURL, privateKeyHex string) (*Chain, error) {
	client, err := ethclient.DialContext(ctx, rpcURL)
	if err != nil {
		return nil, fmt.Errorf("rpc dial: %w", err)
	}
	key, err := crypto.HexToECDSA(trimKey(privateKeyHex))
	if err != nil {
		return nil, fmt.Errorf("private key: %w", err)
	}
	from := crypto.PubkeyToAddress(key.PublicKey)
	chainID, err := client.ChainID(ctx)
	if err != nil {
		client.Close()
		return nil, fmt.Errorf("chain id: %w", err)
	}
	return &Chain{client: client, key: key, from: from, chainID: chainID}, nil
}

func (c *Chain) Close() {
	if c != nil && c.client != nil {
		c.client.Close()
	}
}

func (c *Chain) From() common.Address { return c.from }

func (c *Chain) Ping(ctx context.Context) error {
	_, err := c.client.BlockNumber(ctx)
	return err
}

func (c *Chain) Send(ctx context.Context, call Call) (common.Hash, error) {
	nonce, err := c.client.PendingNonceAt(ctx, c.from)
	if err != nil {
		return common.Hash{}, err
	}
	gasPrice, err := c.client.SuggestGasPrice(ctx)
	if err != nil {
		return common.Hash{}, err
	}
	gasLimit := uint64(300_000)
	tx := types.NewTransaction(nonce, call.To, big.NewInt(0), gasLimit, gasPrice, call.Data)
	signed, err := types.SignTx(tx, types.LatestSignerForChainID(c.chainID), c.key)
	if err != nil {
		return common.Hash{}, err
	}
	if err := c.client.SendTransaction(ctx, signed); err != nil {
		return common.Hash{}, err
	}
	return signed.Hash(), nil
}

func (c *Chain) WaitReceipt(ctx context.Context, hash common.Hash) (*types.Receipt, error) {
	deadline := time.Now().Add(30 * time.Second)
	for {
		if err := ctx.Err(); err != nil {
			return nil, err
		}
		receipt, err := c.client.TransactionReceipt(ctx, hash)
		if err == nil && receipt != nil {
			return receipt, nil
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timeout waiting for %s", hash.Hex())
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(200 * time.Millisecond):
		}
	}
}

func trimKey(k string) string {
	if len(k) >= 2 && (k[0:2] == "0x" || k[0:2] == "0X") {
		return k[2:]
	}
	return k
}
