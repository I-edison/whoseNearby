# Paystack — seamless money flow

## User journey
1. **Fund** wallet (Paystack card/USSD/bank)
2. **Confirm & pay** job → money **held** (escrow)
3. Artisan does work → shows completion code
4. Client **confirms** with code → money **released** to artisan wallet
5. Artisan **Withdraw** to bank account

## .env
```env
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxx
PAYSTACK_CALLBACK_URL=http://127.0.0.1:8081
```

Webhook (optional but recommended):
```
https://YOUR_PUBLIC_API/wallet/paystack/webhook
```

## Screens
- Wallet → Fund (Paystack) / Withdraw / Bank / On hold
- Confirm & pay → shows balance, Add money if short, PIN to hold
- Confirm job → completion code releases pay
- Bank account → required before withdraw

## Test cards (Paystack test mode)
See https://paystack.com/docs/payments/test-payments
