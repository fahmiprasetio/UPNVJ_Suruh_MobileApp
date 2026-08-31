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
request. The client describes what they need, an admin reads it and asks questions in the
order's own chat, then sends a quote with a price, an estimated duration, and a schedule
the team can commit to. The client can accept, ask for it to be recalculated with a stated
reason, or decline and cancel. A request for recalculation lands in the order's chat, so
the answer sits in the same place as the question.

Prices never come from the client on either track. They are computed and held server side.

## Order lifecycle

```mermaid
stateDiagram-v2
    [*] --> Request: Track B submitted
    [*] --> AwaitingPayment: Track A placed

    Request --> AwaitingApproval: admin sends a quote
    AwaitingApproval --> Request: client asks for a recalculation
    AwaitingApproval --> AwaitingPayment: client accepts
    AwaitingApproval --> Cancelled: client declines

    AwaitingPayment --> FindingRunner: gateway confirms payment
    FindingRunner --> InProgress: runner quota filled
    InProgress --> Done: runner closes with photo evidence

    Request --> Cancelled
    AwaitingPayment --> Cancelled
    Done --> [*]
    Cancelled --> [*]
```

What moves an order out of `AwaitingPayment` is the gateway, not the screen and not the
client. There is no way for the app to declare itself paid.

A paid order cannot be cancelled through the cancel endpoint, because cancelling it means
money has to go back, and a refund should not happen as the side effect of one button.

Jobs that need more than one person stay broadcast until the quota is filled. When two
runners accept at the same moment, one wins and the other is told the job was taken. That
race is settled in the database, under a serializable transaction with optimistic
concurrency, rather than in the interface.

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

Working end to end: registration and sign in, both order tracks, quotes, payment,
broadcasting and claiming jobs, order chat, completion with photo evidence, and role
assignment.

Not built yet:

- The admin dashboard. Its endpoints exist, the web surface does not.
- Live updates. The app still polls; the SignalR hub is in place but not yet consumed.
- Object storage for photo evidence, which starts to matter once there is more than one
  server.
- The payment gateway itself, pending the partner's choice. The flow, the contracts, and
  the webhook are already in their real shape.
- The food delivery form, pending a decision on who fronts the cost of the goods.
