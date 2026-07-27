# syntax=docker/dockerfile:1

ARG BASE_IMAGE=itzg/minecraft-server:2026.5.4-java25
FROM --platform=linux/amd64 ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Paper Minecraft Server (amd64)"
LABEL org.opencontainers.image.description="x86_64 Minecraft server based on itzg/minecraft-server"

