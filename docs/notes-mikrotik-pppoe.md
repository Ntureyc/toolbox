# Notes: MikroTik, PPPoE and the network side

The network side of the billing platform. Mostly RouterOS scripting and
the accounting API.

## RouterOS basics

The router API is HTTP with a JSON body, not a binary protocol. A
simple session looks like:

    curl -s -X POST http://<router>/rest/system/resource \
      -H 'Content-Type: application/json' \
      -d '{"user":"admin","password":"<pass>","method":"login"}'

The response contains a session id, and every later call has to send
it. Sessions time out; re-login on a 401 rather than retrying blindly.

## Accounting

PPPoE accounting is what the billing platform actually bills on. The
relevant commands:

    /interface/pppoe-client/print
    /interface/pppoe-server/active/print
    /ip/accounting/print

`pppoe-server/active` is the live session list. A subscriber whose
session is missing is not online, whatever the database says.

The accounting service (`/ip/accounting`) is what generates the usage
records that become invoices. It needs to be enabled and set to
`once` or `interval` - if it is off, no usage is recorded and the
invoices are wrong rather than missing, which is worse.

## `simple-api` versus the full API

The full API is heavy for simple read-only calls. `simple-api` takes
plaintext commands and returns a plain result, which is enough for
"print this" and much lighter to integrate.

    curl -s -G http://<router>/rest/simple-api/pppse/active/print \
      --data-urlencode '.proplist=name' \
      --data-urlencode '.proplist=uptime'

## Router configuration drift

The router is the source of truth for who is online; the database is
the source of truth for who should be online. When they disagree, the
platform resyncs the router.

The resync has to be careful about rate limits. A router with a few
hundred subscribers will start dropping requests if you send them all
at once, and a partially applied resync is worse than none.

## Sessions and uptime

Uptime from the router is what the platform uses to decide whether a
session is alive. There are two different notions of uptime and mixing
them up causes customers to be logged out while their session is fine.

- Session uptime: how long this PPPoE session has been up.
- Accounting uptime: how long this session has been recording usage.

The second is always a multiple of the accounting interval, so it
rounds up. Use session uptime for liveness.

## Scripting RouterOS

    :foreach i in=[/ip/dhcp-server/network find] do={
      :put ([/ip/dhcp-server/network get $i address])
    }

Two habits that avoid most errors:

1. `:put` the intermediate values while developing. RouterOS errors are
   frequently a failed `find` returning an empty set, and then the next
   command operating on nothing.
2. Guard against the empty set. `:foreach` over an empty set does
   nothing at all, silently.

## Timeouts and retries

The router is on the same LAN and does not move. When it does not
answer, it is busy, not gone. Retry with backoff and a short timeout
rather than waiting for the default.
