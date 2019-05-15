Yahtzee for the 2600
====================

![Screen shot 1](https://raw.githubusercontent.com/JeremyJStarcher/Yahtzee_2600/master/docs/screenshot1.png)


[Play Online](https://jeremyjstarcher.github.io/Yahtzee_2600/)

*Screen shot is from the Stella emulator*

This version is playable, but there are a few features notworking yet.

* The diced flagged to re-roll are a little funky.
* There is no handling of additional Yahtzees (yet).

## Why?

I grew up in a world of computers with very limited resources.  My first
computer, some 8080 home brew had 512 _bytes_ of RAM.  My second computer,
a VIC-20, had 5K of RAM (only 3.5K) avaiable user space.

Programming was different then.  You focused on speed and memory usage far
more than you worried about things like code reability or reuse.

The languages that we had were simple. Single line `IF` statements,
combined with `GOTO` lead to a different mindset. This was long before the
concept of `structured programming` ever made its way to the hobbiest
level.  Our languages simply didn't support it.

Today I work on applications where I have no problem pulling in megs of data
and taking however long I need to sort it.

I needed a break. Something different.

Enter ...

The *Atari 2600*

with its 127 _bytes_ of RAM.  Yes. 127 _bytes_.  There is no frame buffer.
The CPU spends its time chasing the beam across the TV screen, throwing data
out just in time for the TIA (graphics chip) to dispay it.  Once in a while,
for a few brief moments, you can run your game logic code during the over scan
time and do a few calculations.  Take too long and the screen falls apart.

## Technical details

For those not familiar with Atari 2600 coding, the technique to put the six
digit score across the screen is insanely clever and was thought of by
brilliant people long ago.

I take no credit for it.

What I do take credit for is suppressing the leading zeros on those numbers.

To do that, I abuse the heck out of `BCD` (Binary Coded Decimal).

BCD is a way to force the 6502, which normally does math in binary,  to
do the math in decimal (base 10) instead. Normally

```
$09 + $01 = $0A
```

but, in BCD mode.

```
$09 + $01 = $10
```

BCD is very powerful -- and very easy to convert to a human readable form.
In fact, BCD is the reason why those six digit scores can be displayed at
all.  They are kept in three bytes like:

```
$123456
```

However, this means that a leading `0` would show as a `0`.  I thought that
looked a bit ugly on my Yahtzee game, so I decided that I'd add a new digit
to the BCD scheme.  Enter the digit `A`.

If I wanted to display the numbe `$000003`, but without the leading 0s, I
would code that as  `$AAAAA3`.  Then, in my font table, i simply gave the
letter `A` the graphics of a blank (or an underline).

However, BCD math doesn't include the digit `A`.  So, before doing math,
all `A` symbols must be changed to a `0`. Then, after the math, leading
`0` symbols are changed back to an `A`.

