FROM redis:latest
CMD ["redis-server","--port","6399"]
EXPOSE 6399
