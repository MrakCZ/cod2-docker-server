# CoD2 Dedicated Server

Dockerizovaný Call of Duty 2 dedicated server s podporou CoD2x knihovny a opravenými mapami od eyza. Obsahuje dva oddělené servery - základní server a rifle-only server - společně se serverem pro rychlé stahování herních souborů a map. Přístup k master serverům je blokovaný pro použití serveru čistě mezi přáteli, kterým pošlete adresu pro připojení. Všem uvedeným ve zdrojích děkuji za skvělou práci, která zlepšuje herní zážitek! 

## Co je použito

| Komponenta | Zdroj | Účel |
|---|---|---|
| `cod2_lnxded_1_3_nodelay_va_loc` | [bgauduch/call-of-duty-2-docker-server](https://github.com/bgauduch/call-of-duty-2-docker-server) | Serverová binárka CoD2 1.3 s VA security patchem |
| `libCoD2x.so` | [callofduty2x/CoD2x](https://github.com/callofduty2x/CoD2x) | Neoficiální patch - opravy bugů, vyšší tickrate, HWID bany |
| `zpam_maps_*.iwd` | [eyza-cod2/zpam3](https://github.com/eyza-cod2/zpam3) | Opravené a komunitní mapy |
| `zzz_rifle_mod.iwd` | Součást tohoto repozitáře | Vlastní rifle-only mod - cross-team pušky a sniperky |
| Alpine Linux | Docker Hub | Minimální base image pro runtime |
| Debian bookworm-slim | Docker Hub | Build stage pro 32bit knihovny |

## Architektura

```
┌──────────────────────────────────────────────┐
│ Docker Compose                               │
│                                              │
│  cod2server        — základní server :28976  │
│  cod2server_rifle  — rifle only      :28977  │
│  cod2_dl           — download nginx  :28980  │
│                                              │
│  Sdílená síť: cod2server_net                 │
└──────────────────────────────────────────────┘
```

### cod2server (základní)
- Mapuje `./main` → `/home/cod2/main`
- Načítá `server.cfg`
- Port `28976 TCP/UDP`

### cod2server_rifle
- Mapuje `./main_rifle` → `/home/cod2/main`
- Načítá `rifle_mp.cfg`
- Obsahuje `zzz_rifle_mod.iwd` - rifle menu pro všechny týmy, cross-team zbraně, bez granátů a pistolí
- Port `28977 TCP/UDP`

### cod2_dl (download server)
- Nginx servíruje `.iwd` soubory pro rychlé stahování
- `/dl/default/main/*.iwd` → `./main`
- `/dl/rifle/main/*.iwd` → `./main_rifle`
- Port `28980 TCP`
- Povoleny pouze `GET/HEAD` requesty, pouze `.iwd` soubory, rate limiting

## Struktura repozitáře

```
cod2-docker-server/
├── bin/
│   ├── cod2_lnxded_1_3_nodelay_va_loc   ← staženo přes make update-bin
│   └── libCoD2x.so                       ← staženo přes make update-cod2x
├── main/                                 ← herní soubory základního serveru
│   ├── iw_00.iwd ... iw_15.iwd          ← z originální hry (nedodávány)
│   ├── localized_english_iw*.iwd        ← z originální hry (nedodávány)
│   ├── zpam_maps_*.iwd                  ← staženo přes make update-zpam-maps
│   ├── server.cfg                        ← konfigurace základního serveru
│   └── ...
├── main_rifle/                           ← herní soubory rifle serveru
│   ├── iw_00.iwd ... iw_15.iwd          ← symlinky nebo kopie z main/
│   ├── zpam_maps_*.iwd                  ← staženo přes make update-zpam-maps
│   ├── zzz_rifle_mod.iwd                ← vlastní rifle mod
│   ├── rifle_mp.cfg                      ← konfigurace rifle serveru
│   └── ...
├── web/
│   └── dl-nginx.conf                     ← konfigurace download nginx
├── Dockerfile
├── docker-compose.yaml
└── Makefile
```

## Požadavky

- Docker a Docker Compose
- `make`, `curl`, `unzip`
- Originální herní soubory CoD2 (`.iwd` soubory z retail kopie nebo Steam)

## Nasazení

### 1. Klonování repozitáře

```bash
git clone https://github.com/MrakCZ/cod2-docker-server.git cod2-docker-server
cd cod2-docker-server
```

### 2. Stažení závislostí

```bash
make setup
```

Stáhne:
- `bin/cod2_lnxded_1_3_nodelay_va_loc` - serverová binárka
- `bin/libCoD2x.so` - CoD2x knihovna
- `zpam_maps_*.iwd` - komunitní mapy do `main/` i `main_rifle/`

### 3. Přidání herních souborů

Zkopíruj originální `.iwd` soubory z CoD2 instalace do `main/`:

```bash
cp /cesta/k/hre/main/iw_*.iwd main/
cp /cesta/k/hre/main/localized_english_iw*.iwd main/
```

Pro rifle server zkopíruj stejné soubory do `main_rifle/` (nebo použij symlinky):

```bash
for f in main/iw_*.iwd main/localized_english_iw*.iwd; do
    ln -sf "$(pwd)/$f" "main_rifle/$(basename $f)"
done
```

### 4. Konfigurace serverů

Uprav `main/server.cfg` - nastavení základního serveru:

```
set sv_hostname "Nazev serveru"
set rcon_password "silne_heslo"
set sv_wwwDownload "1"
set sv_wwwBaseURL "http://tvoje-ip-nebo-domena:28980/dl/default"
```

Uprav `main_rifle/rifle_mp.cfg` - nastavení rifle serveru:

```
set sv_hostname "Rifle Only Server"
set rcon_password "silne_heslo"
set sv_wwwDownload "1"
set sv_wwwBaseURL "http://tvoje-ip-nebo-domena:28980/dl/rifle"
```
 
Některé proměnné jsou write-protected — nelze je nastavit v `.cfg` souborech ani přes `rcon` za běhu serveru. Musí být předány přímo při spuštění binárky pomocí `+set`.
 
V Docker Compose se nastavují přes `command`:
 
```yaml
command:
  [
    "+set", "dedicated", "1",
    "+set", "net_port", "28976",
    "+set", "sv_cheats", "0",
    "+set", "sv_punkbuster", "0"
  ]
```
 
| Proměnná | Výchozí | Popis |
|---|---|---|
| `dedicated` | `0` | `0` = Listen server, `1` = Dedicated LAN, `2` = Dedicated Internet |
| `net_port` | `28960` | UDP port serveru |
| `net_ip` | IP hostitele | Síťové rozhraní na které server naváže |
| `sv_cheats` | `0` | `0` = zakázány, `1` = povoleny |
| `sv_punkbuster` | `0` | `0` = vypnut, `1` = zapnut (servery PB jsou od 2016 offline) |
| `fs_homepath` | domovský adresář | Cesta kde server hledá složku `main/` |
| `fs_basepath` | adresář binárky | Záložní cesta k `main/` |
| `fs_path` | `pb` | Cesta ke složce PunkBuster |

### 5. Build a spuštění

```bash
make build
make up
make logs
```

## Makefile příkazy

| Příkaz | Popis |
|---|---|
| `make setup` | Stáhne všechny závislosti (volej při první instalaci) |
| `make update` | Aktualizuje CoD2x, zPAM mapy a binárku |
| `make update-cod2x` | Aktualizuje pouze CoD2x knihovnu |
| `make update-zpam-maps` | Aktualizuje pouze zPAM mapy |
| `make update-bin` | Aktualizuje pouze serverovou binárku |
| `make build` | Sestaví Docker image |
| `make up` | Spustí všechny kontejnery na pozadí |
| `make down` | Zastaví všechny kontejnery |
| `make restart` | Restart všech kontejnerů |
| `make logs` | Zobrazí logy všech kontejnerů |
| `make shell` | Shell do základního serveru |
| `make shell-rifle` | Shell do rifle serveru |

## Jak funguje CoD2x

CoD2x je načtena přes `LD_PRELOAD` - před spuštěním `cod2_lnxded` se načte `libCoD2x.so` která hookuje herní funkce a přidává nové možnosti (vyšší tickrate, HWID bany, opravy bugů). Hráči s CoD2x klientem získají plnou funkcionalitu, vanilla klienti `(1.3)` se mohou připojit také (netestováno). Ke stažení s ohledem na kompatibilitu se serverem použijte verzi pro Váš systém a postupujte podle návodu, viz [callofduty2x/CoD2x](https://github.com/callofduty2x/CoD2x).

Auto-update CoD2x je vypnut (`sv_update 0`) - aktualizace probíhá ručně přes `make update-cod2x` + `make build`.

## Rifle mod

Vlastní `zzz_rifle_mod.iwd` obsahuje:

- `maps/mp/gametypes/_weapons.gsc` - weapon systém bez závislosti na zPAM, cross-team zbraně (každý tým má přístup ke všem puškám bez ohledu na mapu), žádné granáty, žádné pistole, MG odstraněna z map
- `ui_mp/scriptmenus/weapon_*.menu` - přepracované weapon menu s sekcemi Bolt-Action a Sniper

Dostupné zbraně: Kar98k, Lee-Enfield, Mosin-Nagant, Kar98k Scoped, Enfield Scoped, Mosin Scoped, Springfield.

## Zabezpečení

- Kontejnery běží jako neprivilegovaný uživatel `cod2` `(UID 1000)`
- `cap_drop: ALL` + `cap_add: NET_BIND_SERVICE` - minimální Linux capabilities
- `no-new-privileges: true` - zákaz eskalace práv
- Herní soubory mountovány jako `:ro` (read-only)
- Download nginx povoluje pouze `.iwd` soubory, rate limiting 10 req/min
- Master servery blokovány přes `extra_hosts` - server není veřejně viditelný v browser listu

## Porty

| Port | Protokol | Účel |
|---|---|---|
| `28976` | `TCP/UDP` | Základní herní server |
| `28977` | `TCP/UDP` | Rifle herní server |
| `28980` | `TCP` | Download server (wwwDownload) |

## Aktualizace

```bash
make update    # stáhne nejnovější CoD2x a zPAM mapy
make build     # sestaví nový image
make restart   # restartuje servery
```

