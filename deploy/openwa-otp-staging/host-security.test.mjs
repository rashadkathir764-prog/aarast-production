import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scriptUrl = new URL('./host-security.sh', import.meta.url);
const scriptPath = fileURLToPath(scriptUrl);
const source = readFileSync(scriptUrl, 'utf8');

test('staging firewall is LF-only and valid POSIX shell syntax', () => {
  assert.equal(source.includes('\r'), false);
  const candidates =
    process.platform === 'win32'
      ? ['C:/Program Files/Git/bin/sh.exe', 'C:/Program Files/Git/usr/bin/sh.exe']
      : ['/bin/sh'];
  const shell = candidates.find(existsSync);
  assert.ok(shell, 'a POSIX shell is required to validate host-security.sh');
  const result = spawnSync(shell, ['-n', scriptPath], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});

test('staging firewall resolves the active supported reverse proxy', () => {
  assert.match(source, /AARAST_OTP_PROXY_CONTAINER_NAME/);
  assert.match(source, /dokploy-traefik nginx-proxy-manager/);
  assert.match(source, /\.State\.Running/);
  assert.match(source, /docker network connect --gw-priority=-1/);
  assert.doesNotMatch(
    source,
    /npm_container="\$\{NPM_CONTAINER_NAME:-nginx-proxy-manager\}"/,
  );
});

test('staging firewall locks the complete egress chain and entry-rule order', () => {
  for (const destination of [
    '0.0.0.0/8',
    '10.0.0.0/8',
    '100.64.0.0/10',
    '127.0.0.0/8',
    '169.254.0.0/16',
    '172.16.0.0/12',
    '192.0.0.0/24',
    '192.168.0.0/16',
    '198.18.0.0/15',
    '224.0.0.0/4',
    '240.0.0.0/4',
  ]) {
    assert.equal(source.includes(destination), true, destination);
  }
  assert.match(
    source,
    /protected_subnets="10\.77\.50\.16\/28 10\.77\.50\.32\/28 10\.77\.50\.48\/28"/,
  );
  assert.match(source, /assert_chain_rule_order/);
  assert.match(source, /assert_entry_rule_order/);
  assert.match(source, /test "\$firewall_total" -eq "\$firewall_index"/);
  assert.match(source, /docker_user_first.*DOCKER-USER/s);
  assert.match(source, /input_first.*input_second/s);
  assert.match(
    source,
    /while iptables -C DOCKER-USER[\s\S]+iptables -I DOCKER-USER 1/,
  );
  assert.match(
    source,
    /iptables -I INPUT 1 -s "\$staging_supernet" -j REJECT[\s\S]+iptables -I INPUT 1 -s "\$staging_supernet" -m conntrack/,
  );
});
