#!/usr/bin/env bash
# Genera la Wiki de GitHub a partir de la carpeta doc/ y valida los enlaces.
#
# - Copia doc/*.md a <out-dir>.
# - Comprueba que cada enlace relativo apunte a algo que exista en el repositorio.
# - Reescribe los enlaces para que funcionen en la Wiki:
#     [x](Pagina.md#ancla)  -> [x](Pagina#ancla)
#     [x](../src/app.py)    -> [x](<blob-base>/src/app.py)
#     [x](archivo.json)     -> [x](<blob-base>/doc/archivo.json)
#     [x](.)                -> [x](<blob-base>/doc)
# - No toca nada dentro de bloques de código (```) ni de código en línea (`...`).
#
# Uso: build-wiki.sh <doc-dir> <out-dir> <blob-base-url>
#   ej: build-wiki.sh doc build/wiki https://github.com/owner/repo/blob/main
set -euo pipefail

DOC_DIR="${1%/}"
OUT_DIR="${2%/}"
BLOB_BASE="${3%/}"

if [ ! -f "$DOC_DIR/Home.md" ]; then
  echo "❌ Falta $DOC_DIR/Home.md (portada de la wiki)"
  exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# shellcheck disable=SC2016  # el programa perl va entre comillas simples a propósito
DOC_DIR="$DOC_DIR" OUT_DIR="$OUT_DIR" BLOB_BASE="$BLOB_BASE" perl -e '
  use strict; use warnings;
  use File::Basename qw(basename);
  my ($doc, $out, $blob) = @ENV{qw(DOC_DIR OUT_DIR BLOB_BASE)};
  my $docname = basename($doc);
  my $errors = 0; my $pages = 0;

  # Valida y reescribe los enlaces de un trozo de texto que NO es código.
  sub fix {
    my ($text, $file, $line) = @_;
    $text =~ s{\]\(([^)\s]+)\)}{
      my $t = $1; my $path = $t; $path =~ s/#.*//;
      if ($t !~ m{^(https?:|mailto:|#)} && $path ne "" && !-e "$doc/$path") {
        print "❌ $file:$line enlace roto -> $t\n"; $errors++;
      }
      "](" . rewrite($t) . ")"
    }ge;
    return $text;
  }

  sub rewrite {
    my ($t) = @_;
    return $t if $t =~ m{^(https?:|mailto:|#)};
    return "$1$2"                 if $t =~ m{^([^/]+)\.md((?:#.*)?)$};
    return "$blob/$1"             if $t =~ m{^\.\./(.*)$};
    return "$blob/$docname"       if $t eq ".";
    return "$blob/$docname/$t";
  }

  for my $file (sort glob("$doc/*.md")) {
    open my $in, "<:encoding(UTF-8)", $file or die "$file: $!";
    open my $o, ">:encoding(UTF-8)", "$out/" . basename($file) or die $!;
    my $fenced = 0;
    while (my $l = <$in>) {
      if ($l =~ /^\s*```/) { $fenced = !$fenced; print $o $l; next; }
      if ($fenced) { print $o $l; next; }
      # Partes impares = código en línea entre backticks: se dejan intactas
      my @parts = split /(`[^`]*`)/, $l, -1;
      for my $i (0..$#parts) { $parts[$i] = fix($parts[$i], $file, $.) if $i % 2 == 0; }
      print $o join("", @parts);
    }
    close $in; close $o; $pages++;
  }

  if ($errors) { print "❌ $errors enlace(s) roto(s)\n"; exit 1; }
  print "✅ Enlaces internos correctos\n";
  print "✅ Wiki generada en $out ($pages páginas)\n";
'
