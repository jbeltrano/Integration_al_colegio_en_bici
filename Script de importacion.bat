git clone https://github.com/jacordobah/adminACB.git
git clone https://github.com/A-OrtizC/gatewayACB.git
git clone https://github.com/jacordobah/presentationACB.git
git clone https://github.com/jacordobah/geolocaACB.git
git clone https://github.com/dfquintero/webadminACB.git

docker network create acb-net

cd adminACB
docker compose down -v
start docker compose up -d --build
cd ..

cls

cd gatewayACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cls

cd presentationACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cls

cd geolocaACB
if not exist .env copy .env.example .env
docker compose down -v
start docker compose up -d --build
cd ..

cls

cd webadminACB
if not exist .env copy .env.example .env
cd webadminACB\apps\bff
cd ../../
cls
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"
pause
docker compose down -v
start docker compose up -d --build
cd ..
