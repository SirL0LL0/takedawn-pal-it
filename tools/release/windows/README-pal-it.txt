Takedawn @VERSION@ per Windows (x64) - il disco europeo, in italiano

Windows 10 o 11 a 64 bit e un driver grafico con Vulkan (qualsiasi driver
AMD, Intel o NVIDIA attuale).

I dati del gioco
  Takedawn ha bisogno dei dati del gioco dal tuo disco: un'immagine
  (.iso / .xiso) o una cartella estratta di Burnout 3: Takedown,
  @DISC@. Controlla ogni file e li copia in
  %LOCALAPPDATA%\Takedawn PAL\Game. Da un terminale:

      Takedawn.exe --install <immagine-o-cartella>

  Il gioco gira nella lingua che imposti: apri le impostazioni (Back e
  Start, oppure F1), la pagina Display, e scegli la lingua. Il disco
  europeo porta francese, tedesco e italiano: l'inglese non c'è, e se lo
  chiedi il gioco ripiega sul francese, il suo default.

Dove stanno le cose
  %LOCALAPPDATA%\Takedawn PAL    dati del gioco, cache degli shader
  %APPDATA%\Takedawn PAL         salvataggi, impostazioni, log
  Un aggiornamento (un pacchetto nuovo su questo) lascia stare entrambe le
  cartelle.

Come si aggiorna
  1. Chiudi Takedawn.
  2. Estrai il pacchetto nuovo e copialo sopra il vecchio: il programma e
     la DLL vengono sostituiti, i salvataggi, le impostazioni, i dati del
     gioco e la cache degli shader (le due cartelle sopra) restano.

La prima volta
  Takedawn non ha una firma digitale. Quando lo avvii per la prima volta
  Windows SmartScreen puo' dire "Windows ha protetto il PC": scegli
  "Ulteriori informazioni" e poi "Esegui comunque".

Le licenze di tutto quello che c'e' dentro sono nella cartella licenses.
