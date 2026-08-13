'use strict';

const businessContexts = [
  ['identity', ['auth', 'users', 'me', 'contexts']],
  ['planning', ['wedding-plans', 'onboarding']],
  ['finance', ['money', 'budget-categories', 'wedding-costs']],
  ['collaboration', ['sharing', 'contribution-history']],
  ['tasks', ['tasks']],
  ['guests', ['guests']],
  ['marketplace', ['marketplace', 'provider-dashboard']],
  ['messaging', ['conversations']],
  ['notifications', ['notifications', 'push']],
  ['catalog', ['catalogs']],
  ['media', ['media']],
  ['insights', ['dashboard', 'timeline']],
  ['backoffice', ['admin']],
];

const escape = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const contextPattern = ([name, roots]) =>
  `(?:${roots.map(escape).join('|')}|modules/${escape(name)})`;
const allBusinessPaths = businessContexts.map(contextPattern).join('|');
const backofficePermissionContract =
  '^src/modules/backoffice/domain/admin-permissions\\.ts$';
const makeContextRule = (
  name,
  ownRoots,
  sourceRoots,
  extraAllowedTarget = null,
  includeFutureRoot = true,
) => {
  const ownPaths = contextPattern([name, ownRoots]);
  const sourcePaths = [
    ...sourceRoots.map(escape),
    ...(includeFutureRoot ? [`modules/${escape(name)}`] : []),
  ].join('|');
  return {
    name: `context-${name}-cross-context`,
    comment: `Only the same context or another context's public slice is importable from ${name}`,
    severity: 'error',
    from: { path: `^src/(?:${sourcePaths})(?:/|$)` },
    to: {
      path: `^src/(?:${allBusinessPaths})(?:/|$)`,
      pathNot: [
        `^src/${ownPaths}(?:/|$)` ,
        '^src/modules/[^/]+/public(?:/|$)',
        ...(extraAllowedTarget ? [extraAllowedTarget] : []),
      ],
    },
  };
};
const contextRules = businessContexts.flatMap(([name, ownRoots]) => {
  if (name === 'identity') {
    return [
      makeContextRule(name, ownRoots, ['auth'], backofficePermissionContract, false),
      makeContextRule(name, ownRoots, ownRoots.filter((root) => root !== 'auth')),
    ];
  }
  if (name === 'catalog') {
    return [
      makeContextRule(name, ownRoots, ['catalogs'], backofficePermissionContract, false),
      makeContextRule(name, ownRoots, []),
    ];
  }
  return [makeContextRule(
    name,
    ownRoots,
    ownRoots,
  )];
});

module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      from: {},
      to: { circular: true },
    },
    ...contextRules,
    {
      name: 'domain-no-nest-runtime',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain(?:/|$)' },
      to: { path: '^(?:node_modules/)?@nestjs/' },
    },
    {
      name: 'platform-no-business-contexts',
      severity: 'error',
      from: { path: '^src/platform(?:/|$)' },
      to: { path: `^src/(?:${allBusinessPaths})(?:/|$)` },
    },
    {
      name: 'shared-kernel-is-foundational',
      severity: 'error',
      from: { path: '^src/shared-kernel(?:/|$)' },
      to: { path: `^src/(?:platform|${allBusinessPaths})(?:/|$)` },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsConfig: { fileName: 'tsconfig.json' },
    tsPreCompilationDeps: true,
    reporterOptions: { dot: { collapsePattern: 'node_modules/[^/]+' } },
  },
};
