# Dockerfile — tolerant build (works even if package.json missing)
FROM node:18

WORKDIR /app

# copy everything first (safe) then attempt npm install only if package.json exists
COPY . .

# If package.json exists, run npm install to install dependencies.
# Use a shell form that returns 0 if not present, so build doesn't fail.
RUN if [ -f package.json ]; then \
      echo "package.json found — installing dependencies" && npm ci --only=production || npm install --only=production; \
    else \
      echo "No package.json found — skipping npm install"; \
    fi

EXPOSE 3000

# If package.json has a start script, use npm start; otherwise fallback to node server.js if present
CMD if [ -f package.json ] && grep -q "\"start\"" package.json; then \
      npm start; \
    elif [ -f server.js ]; then \
      node server.js; \
    else \
      echo "No start defined. Container will sleep. Mount app or add package.json start script." && tail -f /dev/null; \
    fi
