# Internet matchmaking

The game connects to one public secure WebSocket endpoint. Players never enter an IP or host a match.

The service queues players, gives each room an authoritative simulation, starts immediately at four
players or after five seconds with at least two players, and fills empty slots with bots.
Two-player matches place the humans on opposite teams. Disconnects turn the departed fighter into a bot.
Rooms are independent. Cancel closes the connection and removes the player from the queue.

## Hosting

Deploy the project root using the included Dockerfile. Railway configuration is included.
The process reads PORT from the environment; the default is 8080. The hosting reverse proxy must
support WebSocket upgrades and terminate TLS. The public URL must be wss://, not an IP field.
The image imports the original project resources during its build and runs Godot 4.7.2 headlessly
as an unprivileged user. Twelve concurrent matches and 64 connected clients are the initial limits.
Snapshot rate is 20 Hz; gameplay input is sent at 30 Hz. Player packets are bounded and rate limited.

After deployment, put the public URL in the project-root online.cfg:

    [matchmaking]
    server_url="wss://YOUR-SERVICE-DOMAIN"

Then export/distribute the client project with that configuration. This URL is developer configuration;
there is no URL or IP entry in the player interface. An empty URL shows a clear unavailable message,
never a fake populated queue. No production URL is configured before a real service is deployed.

The environment variable ELEMENT_SERVER_URL overrides the file for testing or development.
Only local loopback addresses can use ws://. Internet connections require wss:// with normal
certificate verification.

## Local test

Start:

    godot --headless --path . --script res://server/matchmaker.gd

In a separate process set ELEMENT_SERVER_URL=ws://127.0.0.1:8080, then run:

    godot --headless --path . --script res://verify_matchmaking.gd

The test checks two-player pairing, four-player pairing, authoritative input, selected elements,
cancellation, disconnect replacement and independent rooms.

Native Android exports must have the INTERNET permission. iOS builds need their normal network
and signing setup. The server/client protocol version is 11; all clients must use this build.
The server listens only for the game protocol and does not serve local files.

## Current deployment state

The implementation is tested locally. A permanent public deployment requires a connected hosting
account. Docker build and real Android/iOS/macOS clients have not yet been verified.

References:
https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html
