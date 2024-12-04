# FANtium smart contracts

## Token IDs generation

```
1234 56 7890
└┬─┘ ├┘ └┬─┘
 │   │   │
 │   │   └────► token number [0-9999]
 │   │
 │   └────────► version number [0-99]
 │
 └────────────► collection id
```

12 00 0002 burned
12 01 0002 minted as a replacement

3x distribution events
start with 13 00 0001

12 00 0001 burned
12 01 0001 minted as a replacement
12 01 0001 burned
12 02 0001 minted as a replacement
12 02 0001 burned
12 03 0001 minted as a replacement => final token

1MATIC = 1e18
1 500 000 ..000 = 1.5 MATIC

6 decimals = 1,000,000 = 1 USDC

tournamentEarningShare1e7=123 =>

```
   123
----------
10,000,000
```

0,00635%

$2M gain
pershare = 2,000,000 \* 123 / 10,000,000

BPS on a base 10,000

If FANtium cutr is 5% it means that the athlete share is 95%

Primary sales => value v
fantium gets v _ fantium_cut
athlete gets v _ (1 - fantium_cut)

Secondary sales: three actors

1. seller
2. athlete takes x%
3. FANtium takes y%

FANtium gets v _ y
athlete gets v _ x
seller gets v \* (1 - x - y)

exemple FANTIUM cut is 2% athelete cut is 5%, sale is $100

FANtium gets 2
athlete gets 5
seller gets 93

total 100
