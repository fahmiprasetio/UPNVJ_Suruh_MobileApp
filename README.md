# UPNVJ Suruh

An errand and odd-job service for students at UPN Veteran Jakarta, built as a mobile app
for clients and runners on top of a REST API.

A client places an order, the system broadcasts the job to available runners, and the
first runner to accept it takes the work. Conversation, payment, and completion evidence
all stay attached to the order they belong to.

Clients and runners share a single app. The surface that opens is decided by the role in
use rather than by a separate build, and one account may hold both.

## Stack

- **Mobile:** Flutter, Dart, Riverpod for state, GoRouter for navigation
- **API:** ASP.NET Core on .NET 10, Entity Framework Core, SignalR
- **Database:** PostgreSQL
- **Auth:** JWT bearer tokens, one time codes over phone number
- **Payments:** QRIS through a payment gateway, confirmed by webhook

## Service tracks

Six catalogued services: ride and drop off, food delivery, item delivery, moving out of a
boarding house, boarding house cleaning, and bathroom cleaning. Anything outside the list
goes through a free form request.

The split is not cosmetic. It is about who decides the price.

**Track A** covers services whose price follows from the form: ride and drop off, food
delivery, item delivery. The client sees the total before ordering, and the job is
broadcast as soon as it is paid.

**Track B** covers work that a form cannot price on its own, along with every free form
request, and it works like a ride-hailing bidding flow rather than a single centralized
quote. The client describes what they need and names a price they're willing to pay, and
the request broadcasts to every available runner. Any runner who's interested can either
accept the client's suggested price outright or submit a counter-offer of their own — an
order can have several offers pending at once, one per runner, and each runner negotiates
with the client in their own private thread, invisible to every other runner bidding on the
same request. The client can accept one offer, reject it, or ask for a recalculation with a
stated reason (which lands in that same private thread); accepting one offer immediately
closes every other pending offer on that order, and the winning runner is the one who does
the job — there's no separate hand-off to someone else afterward. Admin no longer sets
Track B prices at all; its role is purely monitoring and reconciliation now.

Prices never come from the client alone on either track — a client-suggested price on
Track B is just the opening bid, not a binding number, and the price that actually sticks
still only ever comes from a runner's offer the client accepts, computed and held server
side exactly as before.

## Order lifecycle

```mermaid
stateDiagram-v2
    [*] --> Request: Track B submitted, with a suggested price
    [*] --> AwaitingPayment: Track A placed

    Request --> Request: runners submit competing offers
    Request --> AwaitingPayment: client accepts one offer (the rest auto-close)
    Request --> Cancelled

    AwaitingPayment --> InProgress: Track B, quota of one already met by the winning bidder
    AwaitingPayment --> FindingRunner: Track A, or Track B still short of its runner quota
    FindingRunner --> InProgress: runner quota filled
    InProgress --> Done: runner closes with photo evidence

    AwaitingPayment --> Cancelled
    Done --> [*]
    Cancelled --> [*]
```

What moves an order out of `AwaitingPayment` is the gateway, not the screen and not the
client. There is no way for the app to declare itself paid.

A paid order cannot be cancelled through the cancel endpoint, because cancelling it means
money has to go back, and a refund should not happen as the side effect of one button.

Jobs that need more than one person stay broadcast until the quota is filled. On Track B,
the runner whose offer got accepted fills one slot the moment payment clears — no race
there, the client already chose them. Any slots still open after that (a multi-runner job
like a move-out needs more hands than the one who bid) get broadcast exactly like Track A,
and when two runners accept the same slot at the same moment, one wins and the other is
told the job was taken. That race is settled in the database, under a serializable
transaction with optimistic concurrency, rather than in the interface.

## Layout

```
mobile/    Flutter application
backend/   ASP.NET Core Web API and EF Core
```

## Getting started

Requires Flutter 3.41 or newer, the .NET 10 SDK, and PostgreSQL.

### API

Secrets are not kept in the repository, so each machine sets them once through
`dotnet user-secrets`: the connection string, the JWT signing key, and the payment webhook
secret. The server refuses to start while any of them is missing, and says which, because
a failure at startup is far easier to trace than a failure on the first sign in.

```
cd backend/src/UpnvjSuruh.Api
dotnet user-secrets set "ConnectionStrings:Default" "<postgres connection string>"
dotnet user-secrets set "Jwt:SigningKey" "<random text, at least 32 characters>"
dotnet user-secrets set "Webhook:Secret" "<random text, at least 32 characters, different>"
dotnet ef database update
dotnet run
```

Swagger is served at `/swagger` in development only.

### App

The API address is supplied at build time rather than written into the source:

```
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5059
```

`10.0.2.2` is how the Android emulator refers to localhost on the host machine, and it is
also the default. On a physical device, use the machine's address on the same network.

To work on screens without a server or a database:

```
flutter run --dart-define=SUMBER_DATA=tiruan
```

### Android release

A release build needs its own keystore. The debug keystore that ships with Flutter is not
an option, since its key is public and identical on every machine. Until `key.properties`
exists, `flutter build apk --release` produces an unsigned APK that will not install, and
that is deliberate. See `mobile/android/key.properties.contoh`.

## Testing

```
cd mobile && flutter test
cd backend && dotnet test
```

The API tests start the application in process with their own configuration, so a run
gives the same result on any machine and does not depend on the secrets installed there.

Some of them create a throwaway PostgreSQL database and drop it afterwards. That is on
purpose: what those tests cover is exactly what an in memory provider does not have, and a
test that passes because the provider enforces nothing is worse than no test at all.

## Status

Working end to end on the backend, covered by its test suite (279 passing against a real
Postgres instance, not an in-memory stand-in): registration and sign in, Track A pricing,
Track B's multi-runner bidding (suggested price, competing offers, per-runner private
threads, accept-closes-the-rest, direct assignment of the winning bidder), payment,
broadcasting and claiming jobs, order chat, completion with photo evidence, and role
assignment.

Not built yet:

- **The mobile app's Track B screens.** They still reflect the old design (a single
  centralized admin quote) — there's an admin-offer panel and offer card built around one
  quote per order, and the API client calls the old single-offer routes. None of that
  matches the backend anymore: the runner-bidding endpoints, multi-offer responses, and
  per-runner chat threads described above need their own mobile-side rework (new
  runner-facing "make an offer" screen, a client-facing screen to compare and choose among
  several runners' offers, and a chat screen that can address one runner's thread out of
  several). Track A screens are unaffected.
- The admin dashboard. Its endpoints exist, the web surface does not.
- Live updates. The app still polls; the SignalR hub is in place but not yet consumed.
- Object storage for photo evidence, which starts to matter once there is more than one
  server.
- The payment gateway itself, pending the partner's choice. The flow, the contracts, and
  the webhook are already in their real shape.
- The food delivery form, pending a decision on who fronts the cost of the goods.
