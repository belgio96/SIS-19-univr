#!/bin/sh
# Script per installare sis
# Autore: Alessandro Righi
# Storia dello script: ho creato questo script lo scorso anno per facilitare la 
# compilazione del software sis dai sorgenti. Oggi su richiesta del prof. Setti
# miglioro questo script per renderlo migliore ed affidabile. Fra le varie 
# modifiche, lo script è stato scritto in standard POSIX (funziona su tutte le
# shell), sono stati aggiunti commenti, migliorati i controlli, inserito un 
# output più informativo.

# Dichiarazione dele variabili globali. In genere uno script bash ben fatto pone
# tutti i parametri di esecuzione all'inizio in maniera tale che l'utente finale
# li possa facilmente modifcare. 

# NB: In bash gli spazio contano! Una cosa del tipo
#   VAR = "hello"
# non funzionerà!
# Non si devono inserire spazi prima e dopo l'uguale!
# NB2: In bash le variabili si dichiarano normalmente, ma per accedervi dopo si 
# dovrà anteporvi il simbolo $. 
# echo VAR   NO!
# echo $VAR  OK

# Questi sono i parametri per GCC. È necessario compilare usando lo standard GNU
# 90 essendo il programma molto vecchio. Il parametro di GCC -O3 serve ad 
# indicare di ottimizzare al massimo il codice, in modo che sia presumibilmente 
# più veloce.
CFLAGS="-std=gnu90 -O3"

# Indica quale compilatore utilizzare. 
CC="gcc"

# L'opzione MAKEOPTS come indica le opzioni da passare al programma GNU Make. L'
# opzione -j in particolare dice a make quante compilazioni contemporaneamente 
# eseguire, in modo da velocizzare la compilazione. Avendo una CPU multicore 
# generalmente si consiglia di settare questa opzione a  numero di core + 1. 
# Settata a 4 in quanto penso tutti abbiano più o meno un quad core.
MAKEOPTS="-j4"

# PREFIX imposta la directory in cui si vuole installare sis. Normalmente i 
# programmi compilati dall'utente vanno installati in /usr/local. Installandolo
# in un diverso percorso si facilita la rimozione del programma, tuttavia
# dopo si dovrà manualmente modificare il PATH di sistema per poter utilizzare
# il programma. Nei PC del laboratiorio il percorso è /usr/local/sis/
PREFIX="/usr/local/"
# PREFIX="/usr/local/sis" # <= decommentare per installare in /usr/local/sis

# Url da cui scaricare i sorgenti di SIS. 
# Qui è possibile personalizzare l'URL per scaricare i sorgenti da altre fonti.
# I sorgenti però devono essere patchati per poter funzionare.
URL="http://drive.google.com/uc?id=0B7u7YEROcguHdjgzcHJiU0swcXM"

# Il comando mktemp crea una directory temporanea, con un nome random, in /tmp.
# Il path di questa directory è salvato quindi nella variabile WORKDIR. 
# NB: $(comando) significa, esegui "comando" e ritorna il suo output, che 
# in questo caso viene salvato nella variabile WORKDIR. Un metodo equivalente
# per effettuare questa operazione è usare i "backquotes" così: VAR=`comando`
WORKDIR=$(mktemp -d)

# Come prima, eseguo il comando uname e ne salvo l'output nella variabie OS.
# Il comando uname ottiene il nome del sistema operativo installato, per esempio
# Linux nel caso di Linux, Darwin nel caso di Mac, Cygwin per Windows, etc
OS=$(uname)

echo "Installazione di sis 1.3.6"

# Se abbiamo un MAC, stampo un messaggio di errore: non compila su MAC!
# Notare la sintassi particolare dell'if: anche qua gli spazi contano!
if [ "$OS" = "Darwin" ]; then
    echo "Apparentemente stai compilando questo programma su un Mac. La compilazione su"
    echo "Mac non è supportata da questo script. È consigliabile installare il pacchetto"
    echo "precompilato."
    exit 1
fi

# Verifica se le dipendenze sono soddisfatte.
# Notare la sintassi dell' if e gli operatori logici. Notare che in bash TRUE è 0
# e FALSE valore diverso da 0!
echo "Controllo dipendenze..."
if ! type flex || ! type yacc || ! type make || ! type gcc || ! type curl; then
  echo "Errore: dipendenze mancanti"
  
  # Se ho apt, installo le dipendenze con esso
  if type apt-get; then
    echo "Tentativo di installazioen delle dipendenze con apt"
    sudo apt-get update
    sudo apt-get install -y make bison flex build-essential curl
  else 
    echo "Non stai utilizzando un sistema Debian-based. Installa le dipendenze manualmente"
    echo "usando il gestore pacchetti della tua distribuzione."
    exit 1
  fi
else
  echo "Tutte le dipendenze sono soddisfatte"
fi

# Mi sposto nella directory di lavoro
cd $WORKDIR

# Scarico i sorgenti e li unzippo. Notiamo l'uso della pipeline: il comando 
# curl scarica i dati da internet, che sono passati a gunzip che li decomprime
# ed infine a tar che estrae l'archivio. Questo consente di estrarre i file 
# mentrw il download è ancora in corso, risparmiando tempo (forse su 5Mb no...) 
# L'if serve per controllare il valore di ritorno: in caso uno fra curl o gunzip
# o tar viene stampato un messaggo di errore e si esce. Ricordarsi sempre che 
# in bash true è 0 e false è 1 o valore != 0!
echo "Scaricamento e scompattazione sorgenti, prego attendi"
if ! curl -L $URL | gunzip | tar -x; then
    echo "Errore: impossibile scaricare i file."
    echo "Controlla la connessione ad internet!"
    exit 1
fi

# Mi sposto nella directory di SIS appena estratta
cd sis-1.3.6

echo "Compilazione sorgenti"

# La compilazione di un software su Linux si svolge generalmente in 3 fasi:
#   - configurazione (./configure)
#   - compilazione   (make)
#   - installazione  (make install)

# La fase di configurazione va prima di tutto a testare i vari componenti 
# necessari per la compilazione (compilatori, librerie, ecc) e nel caso ne 
# segnala la mancanza, fatto ciò va a generare i Makefile necessari per
# la compilazione, e i file header config.h per configurare i sorgenti.

# Generalmente si indica il parametro prefix che dice dove si vuole 
# installare il programma (tipicamente /usr/local). Prima di invocare 
# configure setto le variabili CC e CFLAGS in modo da dire quali compilatoi
# e flag make deve usare.
echo "1) configurazione del pacchetto"
if ! CC=$CC CFLAGS=$CFLAGS ./configure --without-x --prefix=$PREFIX; then
    echo "Errore di configurazione!"
    exit 1
fi

# La fase make è la fase di compilazione vera e propria. Il programma make
# legge le istruzioni contenute nei Makefile, generati al passo precedente,
# e va a generare mediante compilatori ed altri programmi ausiliari i vari 
# binari eseguibili. Il parametro -j come citato prima indica quanti processi
# paralleli di make avviare (per sistemi multi core)
echo
echo "2) compilazione del pacchetto (può richiedere del tempo !)"
if ! make $MAKEOPTS; then
    echo "Errore di conpilazione!"
    exit 1
fi

# L'ultima fase, l'installazione, va ad installare i file, mettendoli nel 
# prefix di installazione che abbiamo indicato durante il configure. Tipicamente
# è necessario eseguire questa fase con privilegi di root, per cui il comando 
# viene invocato mediante sudo.
echo
echo "3) installaizone del pacchetto (richiede privilegi di root!)"
if ! sudo make install; then
    echo "Errore di installazione"
    exit 1
fi

# Rimuovo la directory temporanea prima creata
echo "I: rimozione cartelle temporanee"
rm -rf $WORKDIR

if echo "quit" | sis; then 
    echo
    echo "Installazione terminata con successo!"
    exit 0
else 
    echo "Errore di installazione"
    exit 1
fi
