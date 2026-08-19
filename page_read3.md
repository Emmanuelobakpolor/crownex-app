- Body

- Headers (10)

- Body

- Headers (0)

- Body

- Headers (11)

- Body

- Headers (0)

- Body

- Headers (0)

- Body

- Headers (0)

- Body

- Headers (0)

Public

Documentation Settings

ENVIRONMENT

No Environment

LAYOUT

Double Column

LANGUAGE

cURL - cURL

pluginng

Introduction

POST

Login

POST

Register

GET

Get Plans

POST

Buy data

POST

Buy airtime

GET

Fetch Cable Tv plans

POST

Verify Smart card Number

POST

Cable TV Subscription

GET

Fetch Electricity plans

POST

Electricity Bill Payment

POST

Verify Meter Number

GET

Fetch exams plans

POST

Verify Exam Number

POST

Exam Pin Purchase

GET

Get Transaction Status

POST

Webhook Transaction Payload

# pluginng

PLUGINNG API DOCUMENTATION

API RESPONSES

1 is True or successful

0 is pending

4 is failed

2 is manually reversed

### GETFetch Cable Tv plans

https://pluginng.com/api/fetch/bouquet?plan=gotv

AUTHORIZATIONBearer Token

Token

<token>

PARAMS

plan

gotv

gotv, dstv, startimes

Example Request

fetch cable tv plans

View More

curl

```
curl --location -g 'https://sandbox.pluginng.com/api/fetch/bouquet?plan={title}'
```

200 OK

Example Response

- Body

- Headers (10)

View More

json

```
{
  "success": true,
  "data": [
    {
      "variation_code": "gotv-lite",
      "name": "GOtv Lite N410",
      "variation_amount": "410.00",
      "fixedPrice": "Yes"
    },
    {
      "variation_code": "gotv-max",
      "name": "GOtv Max N3,600",
      "variation_amount": "3600.00",
      "fixedPrice": "Yes"
    },
    {
      "variation_code": "gotv-jolli",
      "name": "GOtv Jolli N2,460",
      "variation_amount": "2460.00",
      "fixedPrice": "Yes"
    },
    {
      "variation_code": "gotv-jinja",
      "name": "GOtv Jinja N1,640",
      "variation_amount": "1640.00",
      "fixedPrice": "Yes"
    },
    {
      "variation_code": "gotv-lite-3months",
      "name": "GOtv Lite (3 Months) N1,080",
      "variation_amount": "1080.00",
      "fixedPrice": "Yes"
    },
    {
      "variation_code": "gotv-lite-1year",
      "name": "GOtv Lite (1 Year) N3,180",
      "variation_amount": "3180.00",
      "fixedPrice": "Yes"
    }
  ],
  "message": "Fetched successfully"
}
```

Host

127.0.0.1:8000

Date

Fri, 18 Nov 2022 11:31:10 GMT

Date

Fri, 18 Nov 2022 11:31:10 GMT

Connection

close

X-Powered-By

PHP/8.1.0

Cache-Control

no-cache, private

Content-Type

application/json

X-RateLimit-Limit

120

X-RateLimit-Remaining

116

Access-Control-Allow-Origin

*

### POSTVerify Smart card Number

https://pluginng.com/api/verify/card

AUTHORIZATIONBearer Token

Token

<token>

Bodyformdata

plan

gotv

cardno

1212121212

Example Request

Verify Smart card Number

curl

```
curl --location 'https://pluginng.com/api/verify/card' \
--form 'plan="gotv"' \
--form 'cardno="1212121212"'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### GETFetch exams plans

https://pluginng.com/api/fetch/bouquet?plan={{title}}

AUTHORIZATIONBearer Token

Token

<token>

PARAMS

plan

{{title}}

Example Request

Fetch exams plans

View More

curl

```
curl --location -g 'https://pluginng.com/api/fetch/bouquet?plan={{title}}'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### POSTVerify Exam Number

https://pluginng.com/api/verify/card

AUTHORIZATIONBearer Token

Token

<token>

Bodyformdata

plan

JAMB

cardno

1111111111111

exam number

Example Request

Verify Exam Number

curl

```
curl --location 'https://pluginng.com/api/verify/card' \
--form 'plan="JAMB"' \
--form 'cardno="1111111111111"'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### POSTExam Pin Purchase

https://pluginng.com/api/purchase/exam

AUTHORIZATIONBearer Token

Token

<token>

Bodyformdata

plan

Jamb

required

phonenumber

08068691665

required

cardno

1212121212

required

variation_code

jamb

required

custom_reference

202404151934FWKZC23

Optional

Example Request

Exam Pin Purchase

curl

```
curl --location 'https://pluginng.com/api/purchase/exam' \
--form 'plan="Jamb"' \
--form 'phonenumber="08068691665"' \
--form 'cardno="1212121212"' \
--form 'variation_code="jamb"' \
--form 'custom_reference="202404151934FWKZC23"'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### GETGet Transaction Status

https://pluginng.com/api/requery/202404151934FWKZC23

AUTHORIZATIONBearer Token

Token

<token>

Example Request

Transaction Status

View More

curl

```
curl --location 'https://pluginng.com/api/requery/202404151934FWKZC23'
```

200 OK

Example Response

- Body

- Headers (11)

View More

json

```
{
  "success": true,
  "data": {
    "ref": "9f5878df20",
    "custom_reference": "202404151934FWKZC23",
    "status": "1",
    "description": "MTN SME 1GB for 30 days at N256",
    "response": "Dear Customer, You have successfully shared 1GB Data to 2348104175025. Your SME data balance is 11593.63GB expires 22/05/2024. Thankyou",
    "amount": "256.00",
    "created_at": "2024-04-15T18:34:23.000000Z"
  },
  "message": "Transaction Retrieved successfully."
}
```

keep-alive

timeout=5, max=100

x-powered-by

PHP/8.0.30

cache-control

no-cache, private

content-type

application/json

x-ratelimit-limit

120

x-ratelimit-remaining

115

access-control-allow-origin

*

content-length

406

date

Fri, 19 Apr 2024 10:06:27 GMT

server

LiteSpeed

x-turbo-charged-by

LiteSpeed

### POSTWebhook Transaction Payload

#### We forward to you a payload of your current transaction status as an Array.

NB: To get a payload, you have to make sure you fill the webhook url section found under your profile section on pluginng.com

{
"id": 2885625,
"ref": "5caf087ab0",
"user_id": "67",
"subcategory_id": "1",
"plan": "MTN SME 1GB for 30 days at N0",
"amount": "256.00",
"quantity": "1",
"subtotal": "256.00",
"total": "256.00",
"phone": "08068691665",
"iuc": null,
"meter": null,
"bal": "2576.87",
"prev_bal": "2320.87",
"description": "MTN SME 1GB for 30 days at N256",
"status": 1,
"channel": "Web",
"response": "Dear Customer, You have successfully shared 1GB Data to 2348068691665. Your SME data balance is 22949.55GB expires 29/05/2024. Thankyou",
"custom_reference": "202404221656ZODAI29",
"created_at": "2024-04-22T15:56:30.000000Z",
"updated_at": "2024-04-22T15:56:32.000000Z"
}

Example Request

Webhook Transaction Payload

curl

```
curl --location ''
```

Example Response

- Body

- Headers (0)

View More

Text

```
{
  "id": 2885625,
  "ref": "5caf087ab0",
  "user_id": "67",
  "subcategory_id": "1",
  "plan": "MTN SME 1GB for 30 days at N0",
  "amount": "256.00",
  "quantity": "1",
  "subtotal": "256.00",
  "total": "256.00",
  "phone": "08068691665",
  "iuc": null,
  "meter": null,
  "bal": "2576.87",
  "prev_bal": "2320.87",
  "description": "MTN SME 1GB for 30 days at N256",
  "status": 1,
  "channel": "Web",
  "response": "Dear Customer, You have successfully shared 1GB Data to 2348068691665. Your SME data balance is 22949.55GB expires 29/05/2024. Thankyou",
  "custom_reference": "202404221656ZODAI29",
  "created_at": "2024-04-22T15:56:30.000000Z",
  "updated_at": "2024-04-22T15:56:32.000000Z"
}
```

No response headers

This request doesn't return any response headers
