# Notes: EPS and COD payment handling

Both payment paths exist in the codebase and they fail in different
ways. These are the notes I keep coming back to.

## COD

Cash on delivery. The order is created and the money is collected at
delivery. The states matter:

    PENDING -> CONFIRMED -> DELIVERED
                   |
                   v
                CANCELLED
                   |
                   v
                RETURNED

The rule that keeps biting: **a returned order is not a cancelled
order.** A cancelled order never shipped, so the courier is not
involved and nothing is refunded. A returned order was collected by the
courier and came back, so the money has to be collected back.

Treating them the same means either charging a customer twice or
leaving a courier with cash that was never recovered.

## EPS

Electronic payment system - the customer pays through their bank and
the merchant gets an MFS transfer. The flow has three states and one
of them is the important one:

    INITIATED -> PENDING -> SUCCESS
                   |
                   v
                FAILED

### The re-check problem

An EPS payment can sit in `PENDING` for a long time. The customer's
bank request may have been made, the money may be on its way, and the
callback may never arrive - the customer's connection dropped, or the
bank's system did not respond.

The naive fix is to treat `PENDING` as failed after a timeout. That
is wrong, because the money may still arrive afterwards. It arrives
late and the payment is recorded as successful against an order that
was already marked failed.

The correct handling: a re-check must be able to move a
`CANCELLED`/`FAILED` payment back to success if the money turns up
later. The check looks at the merchant transaction id, not at the
current status.

### Idempotency

The callback can arrive more than once. Every handler that changes
payment state has to be idempotent, keyed on the transaction id. If it
is not, a duplicate callback will apply the credit twice.

### Amount validation

The amount in the callback has to be compared against the amount
expected for that order. A mismatch means either a stale order price
or something wrong. Do not credit the order on mismatch - record it
and let a human look.

### The state machine

The transitions are:

- `INITIATED` -> `PENDING`: we sent the request to the gateway.
- `PENDING` -> `SUCCESS`: the callback said the money is in.
- `PENDING` -> `FAILED`: the gateway rejected it, or a re-check found
  no transaction.

`SUCCESS` and `FAILED` are both terminal for the *initiated* attempt,
but not for the *payment* - a later re-check can still flip a failed
payment to success.

## Money as integers

Amounts are stored as integers, never floats. BDT has no subunit that
matters in practice, so the unit is the taka and the column is
`Int`. A float amount of 1234.56 is a bug waiting for a rounding
difference between two systems to become a real discrepancy.
