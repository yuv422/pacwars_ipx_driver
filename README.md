# Pacwars IPX driver.

A simple DOS TSR driver that implements just enough Novel Netware Interrupts to run the 90's Shareware game Pacwars.

I have fond memories of playing this Novell Netware multiplayer game in the computer room at my school.

It is quite hard to get the game running today due to it's reliance on Netware. I decided to try getting the game to work with IPX which is emulated nicely by dosbox.

## Usage

```pac_drv.com [connectionNumber 1..9]```

Each client must be assigned a unique connection number.

## Notes

Pacwars implements a ring style network with each client passing the game state around the circle. The game assumes all packets will be delivered correctly. This doesn't map very well to IPX so the game will lock up quite easily. 


## TODO

* Remove need to manually assign connection numbers to clients.
* Add guarranteed delivery for sent messages

## 
