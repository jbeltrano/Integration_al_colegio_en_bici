cd adminACB
docker compose down -v
start docker compose up -d --build
cd ..

cd gatewayACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cd presentationACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cd geolocaACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cd webadminACB
docker compose down -v
start docker compose up -d --build
cd ..
