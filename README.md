# PdfCraft: correzione della stampa

Con alcune stampanti Brother (per esempio MFC-L3760CDW, MFC-L2710DN, HL-L3230CDW) PdfCraft su
Windows non stampa e mostra `Render Error: Interfaccia non supportata (0x80040003)`. Il driver
rifiuta il PrintTicket della stampa XPS (un `JobPrintSpeed` doppio, vedi
[ArcticLampyrid/winprint.rs#3](https://github.com/ArcticLampyrid/winprint.rs/issues/3)).

Questo repository ricompila ogni nuova versione di [PdfCraft](https://github.com/storytold/pdfcraft)
con la correzione proposta in storytold/winprint.rs#6 e storytold/craft-libs#188: quando il driver
rifiuta la stampa XPS, PdfCraft stampa lo stesso documento tramite GDI (come immagine fino a
300 dpi), passando al driver copie, fronte-retro e formato del lavoro. Le altre stampanti stampano come prima.
Le build sono pubblicate tra le [release](../../releases), con lo stesso numero di versione di
quelle ufficiali.

Sono build **non ufficiali e non firmate**, fatte da GitHub Actions a partire dal codice pubblico
(`.github/workflows/build.yml`): il controllo avviene ogni ora, quindi una nuova versione di
PdfCraft è pronta circa un'ora dopo l'uscita.

## Windows

Una volta sola: scarica `PdfCraft-Stampa-Windows.zip` dalla release
[strumenti](../../releases/tag/strumenti). Prima di estrarlo, aprilo con il tasto destro
› Proprietà › spunta **Annulla blocco** › OK. Estrai la cartella dove preferisci.

Dopo ogni aggiornamento di PdfCraft fatto con l'ArtCraft Launcher:

1. chiudi PdfCraft;
2. fai doppio clic su `Applica-stampa.cmd` (se Windows mostra "PC protetto", scegli
   "Ulteriori informazioni" › "Esegui comunque");
3. quando Windows chiede il permesso di installare, rispondi **Sì** (l'autore risulta
   sconosciuto perché la build non è firmata).

Lo script legge la versione installata, scarica la build della stessa versione, ne controlla
l'impronta SHA-256 e la installa. Se la build non è ancora pronta, te lo dice e non tocca niente.
Quando la versione ufficiale conterrà la correzione, lo script lo dice con una finestra di avviso e
non installa più niente.

Per tornare alla versione ufficiale basta **Reinstalla** nel Launcher.

## Contenuto

- `apply_print_fix.sh`: applica la correzione alle revisioni esatte di craft-libs e winprint che
  usa una versione di PdfCraft. Riconosce quando le sorgenti ufficiali contengono già una
  correzione.
- `patches/`: le due modifiche (craft-print e winprint).
- `windows/`: la patch per Windows.

Le modifiche seguono le licenze dei progetti da cui vengono (craft-libs: MIT OR Apache-2.0;
winprint: BSD-3-Clause).
