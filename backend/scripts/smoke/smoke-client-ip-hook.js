'use strict';

// The full smoke suite intentionally represents many independent clients but
// runs from one local process host. Give each child script a distinct reserved
// benchmark-range address through the same X-Forwarded-For contract used by
// the trusted local reverse-proxy hop. Product throttle limits remain intact.
const http = require('http');

const smokeClientIp = process.env.SMOKE_CLIENT_IP;
if (smokeClientIp) {
  const originalRequest = http.request;
  http.request = function patchedRequest(options, ...args) {
    if (options && typeof options === 'object' && !(options instanceof URL)) {
      options = {
        ...options,
        headers: {
          ...(options.headers || {}),
          'X-Forwarded-For': smokeClientIp,
        },
      };
    }
    return originalRequest.call(this, options, ...args);
  };
}
