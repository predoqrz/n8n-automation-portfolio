# Postgres 16 Alpine — a mesma imagem de antes — com a extensão pgvector compilada.
#
# Por que não a imagem oficial pgvector/pgvector:pg16: ela é baseada em Debian. O banco
# já existente foi criado no Alpine com collation en_US.utf8, que no Alpine (musl) ordena
# texto de um jeito e no Debian (glibc) de outro. Trocar de base sobre o mesmo volume
# deixaria índices de texto inconsistentes sem erro nenhum. Compilando aqui, nada muda
# para os dados que já existem.
FROM postgres:16-alpine

ARG PGVECTOR_VERSION=v0.8.7

RUN apk add --no-cache --virtual .build-deps git build-base \
 && git clone --depth 1 --branch ${PGVECTOR_VERSION} https://github.com/pgvector/pgvector.git /tmp/pgvector \
 && cd /tmp/pgvector \
 # OPTFLAGS vazio: sem -march=native, a imagem roda em qualquer CPU, não só na que compilou.
 # with_llvm=no: pula o bitcode de JIT, que exigiria a mesma versão de LLVM do Postgres.
 && make OPTFLAGS="" with_llvm=no \
 && make install with_llvm=no \
 && cd / && rm -rf /tmp/pgvector \
 && apk del .build-deps
