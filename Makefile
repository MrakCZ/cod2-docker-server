.PHONY: setup update update-cod2x update-zpam-maps update-bin build up down logs restart shell shell-rifle

setup: update
	@echo "✅ Hotovo — zkopíruj iw_XX.iwd (00-15) a localized_*_iwXX.iwd soubory z originální hry do main/ a main_rifle/ (případně použít symlink z main do main_rifle) a spusť: make build"

update: update-cod2x update-zpam-maps update-bin

update-cod2x:
	$(eval VERSION := $(shell curl -s https://api.github.com/repos/callofduty2x/CoD2x/releases/latest | grep tag_name | cut -d'"' -f4))
	$(eval FILENAME := CoD2x_$(subst v,,$(VERSION))_linux.zip)
	@echo "Stahuji CoD2x $(VERSION)..."
	mkdir -p bin
	curl -L "https://github.com/callofduty2x/CoD2x/releases/download/$(VERSION)/$(FILENAME)" -o cod2x.zip
	unzip -o cod2x.zip libCoD2x.so
	mv libCoD2x.so bin/libCoD2x.so
	chmod +x bin/libCoD2x.so
	rm cod2x.zip
	echo "$(VERSION)" > .cod2x-version
	@echo "✅ CoD2x $(VERSION) připravena"

update-zpam-maps:
	$(eval VERSION := $(shell curl -s https://api.github.com/repos/eyza-cod2/zpam3/releases/latest | grep tag_name | cut -d'"' -f4))
	$(eval FILENAME := zpam$(subst .,,$(VERSION)).zip)
	@echo "Stahuji zPAM mapy $(VERSION)..."
	curl -L "https://github.com/eyza-cod2/zpam3/releases/download/$(VERSION)/$(FILENAME)" -o zpam.zip
	unzip -o zpam.zip -d zpam_tmp
	cp zpam_tmp/main/zpam_maps_*.iwd main/
	cp zpam_tmp/main/zpam_maps_*.iwd main_rifle/
	rm -rf zpam_tmp zpam.zip
	echo "$(VERSION)" > .zpam-version
	@echo "✅ zPAM mapy $(VERSION) připraveny"

update-bin:
	@echo "Stahuji cod2_lnxded..."
	mkdir -p bin
	curl -L "https://raw.githubusercontent.com/bgauduch/call-of-duty-2-docker-server/main/bin/cod2_lnxded_1_3_nodelay_va_loc" -o bin/cod2_lnxded_1_3_nodelay_va_loc
	chmod +x bin/cod2_lnxded_1_3_nodelay_va_loc
	@echo "✅ cod2_lnxded připraven"

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

restart: down up

logs:
	docker compose logs -f

shell:
	docker compose exec cod2_server sh

shell-rifle:
	docker compose exec cod2_server_rifle sh
