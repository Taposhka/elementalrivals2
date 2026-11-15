FROM debian:bookworm-slim
ARG GODOT_VERSION=4.7.2
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libgl1 libfontconfig1 libasound2 && curl -fsSL "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip && unzip -q /tmp/godot.zip -d /usr/local/bin && mv "/usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot && rm /tmp/godot.zip && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . /app
RUN godot --headless --editor --path /app --import --quit && useradd --create-home --uid 10001 element && chown -R element:element /app
USER element
ENV PORT=8080
EXPOSE 8080
CMD ["godot", "--headless", "--path", "/app", "--script", "res://server/matchmaker.gd"]
