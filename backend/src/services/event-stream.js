function createEventStream() {
  const clients = new Set();

  function subscribe(client) {
    clients.add(client);

    return () => {
      clients.delete(client);
      if (typeof client.close === 'function') {
        client.close();
      }
    };
  }

  function publish(eventName, payload) {
    for (const client of clients) {
      client.writeEvent(eventName, payload);
    }
  }

  return {
    subscribe,
    publish,
  };
}

module.exports = {
  createEventStream,
};
