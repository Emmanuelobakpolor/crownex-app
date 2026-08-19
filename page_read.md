- Body

- Headers (0)

- Body

- Headers (0)

- Body

- Headers (11)

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

### POSTLogin

https://pluginng.com/api/login

Live Endpoint: https://pluginng.com/api

HEADERS

Content-Type

application/json

Accept

application/json

Bodyraw

```
{
    "email": "pluginngservice@gmail.com",
    "password": "password"
}
```

Example Request

Login

curl

```
curl --location 'https://pluginng.com/api/login' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--data-raw '{
    "email": "pluginngservice@gmail.com",
    "password": "password"
}'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### POSTRegister

https://pluginng.com/api/register

HEADERS

Content-Type

application/json

Accept

application/json

Bodyraw

```
{
    "email": "pluginngservice@gmail.com",
    "password": "yourpassword",
    "role": "1",
    "firstname": "Name",
    "lastname": "surname",
    "phone": "08068691665"
}
```

Example Request

Register

curl

```
curl --location 'https://pluginng.com/api/register' \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
--data-raw '{
    "email": "pluginngservice@gmail.com",
    "password": "yourpassword",
    "role": "1",
    "firstname": "Name",
    "lastname": "surname",
    "phone": "08068691665"
}'
```

Example Response

- Body

- Headers (0)

No response body

This request doesn't return any response body

No response headers

This request doesn't return any response headers

### GETGet Plans

https://pluginng.com/api/get/plans

Load all plans and codes required to make purchases

AUTHORIZATIONBearer Token

Token

<token>

Example Request

Get Plans

curl

```
curl --location 'https://pluginng.com/api/get/plans'
```

200 OK

Example Response

- Body

- Headers (11)

View More

json

```
{
  "data": [
    {
      "subcategory_id": 1,
      "title": "MTN SME",
      "category": "Data",
      "plan": [
        {
          "plan": "500MB for 30 days",
          "amount": 132
        },
        {
          "plan": "1GB for 30 days",
          "amount": 260
        },
        {
          "plan": "2GB for 30 days",
          "amount": 522
        },
        {
          "plan": "3GB for 30 days",
          "amount": 783
        },
        {
          "plan": "5GB for 30 days",
          "amount": 1305
        },
        {
          "plan": "10GB for 30 days",
          "amount": 2610
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 2,
      "title": "MTN CG",
      "category": "Data",
      "plan": [
        {
          "plan": "50MB [CG] for 30 days",
          "amount": 25
        },
        {
          "plan": "100MB [CG] for 30 days",
          "amount": 42
        },
        {
          "plan": "150MB [CG] for 30 days",
          "amount": 50
        },
        {
          "plan": "250MB [CG] for 30 days",
          "amount": 85
        },
        {
          "plan": "300MB [CG] for 30 days",
          "amount": 126
        },
        {
          "plan": "500MB [CG] for 30 days",
          "amount": 133
        },
        {
          "plan": "1GB [CG] for 30 days",
          "amount": 266
        },
        {
          "plan": "1.5GB [CG] for 30 days",
          "amount": 399
        },
        {
          "plan": "2GB [CG] for 30 days",
          "amount": 532
        },
        {
          "plan": "3GB [CG] for 30 days",
          "amount": 795
        },
        {
          "plan": "5GB [CG] for 30 days",
          "amount": 1320
        },
        {
          "plan": "10GB [CG] for 30 days",
          "amount": 2660
        },
        {
          "plan": "15GB [CG] for 30 days",
          "amount": 3975
        },
        {
          "plan": "20GB [CG] for 30 days",
          "amount": 5320
        },
        {
          "plan": "40GB [CG] for 30 days",
          "amount": 10600
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 3,
      "title": "AIRTEL DIRECT",
      "category": "Data",
      "plan": [
        {
          "plan": "100MB Daily",
          "amount": 86
        },
        {
          "plan": "200MB Daily",
          "amount": 170
        },
        {
          "plan": "2GB for 2 days",
          "amount": 440
        },
        {
          "plan": "350MB for 7 days",
          "amount": 300
        },
        {
          "plan": "750MB for 7 days",
          "amount": 440
        },
        {
          "plan": "1GB for 7 days",
          "amount": 440
        },
        {
          "plan": "6GB for 7 days",
          "amount": 1245
        },
        {
          "plan": "1.2GB for 30 days",
          "amount": 850
        },
        {
          "plan": "1.5GB for 30 days",
          "amount": 1020
        },
        {
          "plan": "3GB for 30 days",
          "amount": 1275
        },
        {
          "plan": "4.5GB for 30 days",
          "amount": 1700
        },
        {
          "plan": "6GB for 30 days",
          "amount": 2125
        },
        {
          "plan": "10GB for 30 days",
          "amount": 2550
        },
        {
          "plan": "15GB for 30 days",
          "amount": 3400
        },
        {
          "plan": "18GB for 30 days",
          "amount": 4250
        },
        {
          "plan": "18GB Router plan for 30 days",
          "amount": 4250
        },
        {
          "plan": "30GB for 30 days",
          "amount": 6800
        },
        {
          "plan": "40GB for 30 days",
          "amount": 8500
        },
        {
          "plan": "40GB Router plan for 30 days",
          "amount": 8500
        },
        {
          "plan": "40GB Ultra Router for 30 days",
          "amount": 8500
        },
        {
          "plan": "75GB for 30 days",
          "amount": 12750
        },
        {
          "plan": "75GB Router plan for 30 days",
          "amount": 12750
        },
        {
          "plan": "75GB Ultra mifi for 30 days",
          "amount": 12750
        },
        {
          "plan": "120GB for 30 days",
          "amount": 17000
        },
        {
          "plan": "120GB Router plan for 30 days",
          "amount": 17000
        },
        {
          "plan": "120GB Ultra Mifi for 30 days",
          "amount": 17000
        },
        {
          "plan": "120GB Ultra Router for 30 days",
          "amount": 17000
        },
        {
          "plan": "200GB Ultra Standard plan for  30 days",
          "amount": 17000
        },
        {
          "plan": "240GB for 30 days",
          "amount": 26100
        },
        {
          "plan": "300GB Ultra Diamond for 30 days",
          "amount": 26100
        },
        {
          "plan": "280GB for 30 days",
          "amount": 31320
        },
        {
          "plan": "400GB for 90 days",
          "amount": 43500
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 4,
      "title": "AIRTEL CG",
      "category": "Data",
      "plan": [
        {
          "plan": "100MB [CG] for 7 days",
          "amount": 31
        },
        {
          "plan": "300MB [CG] for 7 days",
          "amount": 88
        },
        {
          "plan": "500MB [CG] for 30 days",
          "amount": 143
        },
        {
          "plan": "1GB [CG] for 30 days",
          "amount": 285
        },
        {
          "plan": "2GB [CG] for 30 days",
          "amount": 570
        },
        {
          "plan": "5GB [CG] for 30 days",
          "amount": 1425
        },
        {
          "plan": "10GB [CG] for 30 days",
          "amount": 2850
        },
        {
          "plan": "15GB [CG] for 30 days",
          "amount": 4275
        },
        {
          "plan": "20GB [CG] for 30 days",
          "amount": 5700
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 5,
      "title": "GLO DIRECT",
      "category": "Data",
      "plan": [
        {
          "plan": "1GB/1.8GB for 30 days",
          "amount": 410
        },
        {
          "plan": "2.5GB/3.9GB for 30 days",
          "amount": 810
        },
        {
          "plan": "4.1GB/7.5GB for 30 days",
          "amount": 1220
        },
        {
          "plan": "7GB weekly",
          "amount": 1220
        },
        {
          "plan": "5.8GB/9.2GB for 30 days",
          "amount": 1620
        },
        {
          "plan": "7.7GB/10.8GB for 30 days",
          "amount": 2050
        },
        {
          "plan": "10GB/14GB for 30 days",
          "amount": 2420
        },
        {
          "plan": "13.25GB/18GB for 30 days",
          "amount": 3420
        },
        {
          "plan": "18.25GB/24GB for 30 days",
          "amount": 4100
        },
        {
          "plan": "29.5GB for 30 days",
          "amount": 7040
        },
        {
          "plan": "50GB for 30 days",
          "amount": 8800
        },
        {
          "plan": "93GB for 30 days",
          "amount": 13200
        },
        {
          "plan": "119GB for 30 days",
          "amount": 15840
        },
        {
          "plan": "138GB for 30 days",
          "amount": 17600
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 8,
      "title": "MTN",
      "category": "Airtime",
      "status": "1"
    },
    {
      "subcategory_id": 9,
      "title": "Airtel",
      "category": "Airtime",
      "status": "1"
    },
    {
      "subcategory_id": 10,
      "title": "GLO",
      "category": "Airtime",
      "status": "1"
    },
    {
      "subcategory_id": 11,
      "title": "DSTV",
      "category": "Cable",
      "status": "1"
    },
    {
      "subcategory_id": 12,
      "title": "GOTV",
      "category": "Cable",
      "status": "1"
    },
    {
      "subcategory_id": 13,
      "title": "STARTIMES",
      "category": "Cable",
      "status": "1"
    },
    {
      "subcategory_id": 14,
      "title": "Abuja-Electric",
      "serviceID": "AEDC - Abuja Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 15,
      "title": "Ikeja-Electric",
      "serviceID": "IKEDC - Ikeja Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 16,
      "title": "Eko-Electric",
      "serviceID": "EKEDC - Eko Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 21,
      "title": "WAEC",
      "category": "Exam",
      "status": "1"
    },
    {
      "subcategory_id": 22,
      "title": "JAMB",
      "category": "Exam",
      "status": "1"
    },
    {
      "subcategory_id": 24,
      "title": "GLO CG",
      "category": "Data",
      "plan": [
        {
          "plan": "200MB [CG] for 14 days",
          "amount": 51
        },
        {
          "plan": "500MB [CG] for 30 days",
          "amount": 122
        },
        {
          "plan": "1GB [CG] for 30 days",
          "amount": 235
        },
        {
          "plan": "2GB [CG] for 30 days",
          "amount": 470
        },
        {
          "plan": "3GB [CG] for 30 days",
          "amount": 705
        },
        {
          "plan": "5GB [CG] for 30 days",
          "amount": 1200
        },
        {
          "plan": "10GB [CG] for 30 days",
          "amount": 2400
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 25,
      "title": "MTN DIRECT",
      "category": "Data",
      "plan": [
        {
          "plan": "1.5GB + 10Mins weekly plan",
          "amount": 950
        },
        {
          "plan": "5GB weekly plan",
          "amount": 1425
        },
        {
          "plan": "1.2GB + 5Mins for 30days",
          "amount": 950
        },
        {
          "plan": "1.5GB + 5Mins for 30days",
          "amount": 1140
        },
        {
          "plan": "3GB + 5Mins for 30 days",
          "amount": 1536
        },
        {
          "plan": "4GB + 10Mins for 30days",
          "amount": 1900
        },
        {
          "plan": "8GB +15Mins for 30days",
          "amount": 2880
        },
        {
          "plan": "10GB+ 20mins for 30days",
          "amount": 3330
        },
        {
          "plan": "12GB for 30days",
          "amount": 3325
        },
        {
          "plan": "20GB for 30days",
          "amount": 4750
        },
        {
          "plan": "25GB + 25MINS for 30days",
          "amount": 6250
        },
        {
          "plan": "40GB + 40MINS for 30days",
          "amount": 10600
        },
        {
          "plan": "75GB + 40MINS for 30days",
          "amount": 15500
        },
        {
          "plan": "120GB + 80MINS for 30days",
          "amount": 21200
        },
        {
          "plan": "200GB for 30days",
          "amount": 28500
        },
        {
          "plan": "100GB for 60days",
          "amount": 18800
        },
        {
          "plan": "160GB for 60days",
          "amount": 28500
        },
        {
          "plan": "400GB for 90days",
          "amount": 47500
        },
        {
          "plan": "600GB for 90days",
          "amount": 69750
        },
        {
          "plan": "800GB for 180days",
          "amount": 85500
        },
        {
          "plan": "1TB for 365days",
          "amount": 95000
        },
        {
          "plan": "2.5GB yearly plan",
          "amount": 237500
        },
        {
          "plan": "4.5GB yearly plan",
          "amount": 427500
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 27,
      "title": "Kano-Electric",
      "serviceID": "KEDCO - Kano Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 28,
      "title": "PortHarcourt-Electric",
      "serviceID": "PHED - PortHarcourt Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 29,
      "title": "Jos-Electric",
      "serviceID": "JED - Jos Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 30,
      "title": "Ibadan-Electric",
      "serviceID": "IBEDC - Ibadan Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 31,
      "title": "Kaduna-Electric",
      "serviceID": "KAEDCO - Kaduna Electric",
      "category": "Electricity",
      "status": "1"
    },
    {
      "subcategory_id": 40,
      "title": "9MOBILE CG",
      "category": "Data",
      "plan": [
        {
          "plan": "100MB for 30 days",
          "amount": 20
        },
        {
          "plan": "250MB for 30 days",
          "amount": 65
        },
        {
          "plan": "500MB for 30 days",
          "amount": 85
        },
        {
          "plan": "650MB for 30 days",
          "amount": 110
        },
        {
          "plan": "1GB for 30 days",
          "amount": 150
        },
        {
          "plan": "1.5GB for 30 days",
          "amount": 230
        },
        {
          "plan": "2GB for 30 days",
          "amount": 300
        },
        {
          "plan": "3GB for 30 days",
          "amount": 430
        },
        {
          "plan": "4.5GB for 30 days",
          "amount": 660
        },
        {
          "plan": "5GB for 30 days",
          "amount": 700
        },
        {
          "plan": "10GB for 30 days",
          "amount": 1500
        },
        {
          "plan": "11GB for 30 days",
          "amount": 1530
        },
        {
          "plan": "15GB for 30 days",
          "amount": 2300
        },
        {
          "plan": "20GB for 30 days",
          "amount": 2900
        },
        {
          "plan": "25GB for 30 days",
          "amount": 3500
        },
        {
          "plan": "30GB for 30 days",
          "amount": 4500
        },
        {
          "plan": "40GB for 30 days",
          "amount": 6000
        },
        {
          "plan": "50GB for 30 days",
          "amount": 7000
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 42,
      "title": "MTN HYNET",
      "category": "Data",
      "plan": [
        {
          "plan": "12GB  for 30 days",
          "amount": 3850
        },
        {
          "plan": "30GB for 30 days",
          "amount": 7700
        },
        {
          "plan": "45GB for 30 days",
          "amount": 10580
        },
        {
          "plan": "100GB for 30 days",
          "amount": 17300
        },
        {
          "plan": "130GB FUP UNLIMITED for 30 days",
          "amount": 19200
        },
        {
          "plan": "200GB for 30 days",
          "amount": 24000
        },
        {
          "plan": "250GB FUP UNLIMITED for 30 days",
          "amount": 28800
        },
        {
          "plan": "500GB FUP UNLIMITED for 30 days",
          "amount": 43300
        },
        {
          "plan": "800GB FUP UNLIMITED for 30 days",
          "amount": 57600
        },
        {
          "plan": "300GB for 30 days",
          "amount": 34600
        },
        {
          "plan": "400GB for 30 days",
          "amount": 43200
        },
        {
          "plan": "1TB for 6 Months",
          "amount": 86400
        },
        {
          "plan": "2.5TB FUP UNLIMITED for 6 Months",
          "amount": 158500
        },
        {
          "plan": "2TB for 365 days",
          "amount": 144000
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 43,
      "title": "MTN CG LITE",
      "category": "Data",
      "plan": [
        {
          "plan": "50MB [CG] for 30 days",
          "amount": 30
        },
        {
          "plan": "150MB [CG] for 30 days",
          "amount": 50
        },
        {
          "plan": "250MB [CG] for 30 days",
          "amount": 80
        },
        {
          "plan": "500MB [CG] for 30 days",
          "amount": 132
        },
        {
          "plan": "1000MB [CG] for 30 days",
          "amount": 262
        },
        {
          "plan": "2000MB [CG] for 30 days",
          "amount": 524
        },
        {
          "plan": "3000MB [CG] for 30 days",
          "amount": 786
        },
        {
          "plan": "5000MB [CG] for 30 days",
          "amount": 1310
        },
        {
          "plan": "10000MB [CG] for 30 days",
          "amount": 2620
        },
        {
          "plan": "15000MB [CG] for 30 days",
          "amount": 3930
        },
        {
          "plan": "20000MB [CG] for 30 days",
          "amount": 5240
        },
        {
          "plan": "40000MB [CG] for 30 days",
          "amount": 10480
        }
      ],
      "status": "1"
    },
    {
      "subcategory_id": 44,
      "title": "MTN AWOOOF",
      "category": "Data",
      "plan": [
        {
          "plan": "GET 1GB  for 1 Day",
          "amount": 240
        },
        {
          "plan": "GET 3.5GB  for 2 days",
          "amount": 550
        },
        {
          "plan": "GET 5GB  for 30 days",
          "amount": 1150
        },
        {
          "plan": "GET 15GB  for 7 days",
          "amount": 2500
        }
      ],
      "status": "1"
    }
  ]
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

116

access-control-allow-origin

*

content-length

9496

date

Tue, 16 Apr 2024 22:09:19 GMT

server

LiteSpeed

x-turbo-charged-by

LiteSpeed
