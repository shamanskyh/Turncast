# Turncast

Turncast is an open source server/client application designed to easily stream audio input from an analog source (like a record player) to Airplay 2 compatible speakers. To use it, you will need a Mac running as a server as well as an iPhone or Apple TV which acts as the client (and streams to speakers).



Isn't this overkill/unnecessary? Absolutely. There are plenty of much easier ways to play analog audio through speakers, of course, and this is just one implementation that attempts to integrate a record player into a house of HomePods or other Airplay speakers.

## Streaming

Turncast uses [HaishinKit](https://github.com/shogo4405/HaishinKit.swift) to stream audio over your local network using HLS. Your Apple TV or iOS device can then stream to any compatible speakers or play locally through the device. Because of Airplay limitations, there is some latency between your audio source and the final output.

## Metadata & Album Art

Turncast uses ShazamKit to recognize audio being streamed and displays the appropriate metadata on your device and in Control Center. You can override the metadata values in Turncast's settings so that it appears just as you'd like.

## Contributing, Issues, and Pull Requests

I welcome any contributions to this repo -- please feel free to file issues and open pull requests as necessary. This software is provided under the MIT license.
