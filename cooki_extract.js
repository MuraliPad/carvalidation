copy(JSON.stringify(
  document.cookie.split(';')
    .filter(c => c.trim())
    .map(c => {
      const [name, ...rest] = c.trim().split('=');
      return {
        name: name.trim(),
        value: rest.join('=').trim(),
        domain: location.hostname,
        path: '/'
      };
    }),
  null, 2
))
