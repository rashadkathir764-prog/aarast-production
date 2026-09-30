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
const relocatedSafeUser = '^src/modules/identity/public/safe-user\\.ts$';
const makeContextRule = (
  name,
  ownRoots,
  sourceRoots,
  includeFutureRoot = true,
  excludedSource = null,
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
    from: {
      path: `^src/(?:${sourcePaths})(?:/|$)`,
      ...(excludedSource ? { pathNot: excludedSource } : {}),
    },
    to: {
      path: `^src/(?:${allBusinessPaths})(?:/|$)`,
      pathNot: [
        `^src/${ownPaths}(?:/|$)` ,
        '^src/modules/[^/]+/public(?:/|$)',
      ],
    },
  };
};
const contextRules = businessContexts.flatMap(([name, ownRoots]) => {
  if (name === 'identity') {
    return [
      makeContextRule(name, ownRoots, ['auth'], false),
      makeContextRule(
        name,
        ownRoots,
        ownRoots.filter((root) => root !== 'auth'),
        true,
        relocatedSafeUser,
      ),
      {
        ...makeContextRule(name, ownRoots, []),
        name: 'context-identity-relocated-safe-user-cross-context',
        from: { path: relocatedSafeUser },
      },
    ];
  }
  if (name === 'catalog') {
    return [
      makeContextRule(name, ownRoots, ['catalogs'], false),
      makeContextRule(name, ownRoots, []),
    ];
  }
  return [makeContextRule(
    name,
    ownRoots,
    ownRoots,
  )];
});
const publicCrossOwnerRules = businessContexts.map(([name]) => ({
  name: 'public-cross-owner-type-only',
  comment: `Runtime dependencies from ${name} public to another owner public are forbidden`,
  severity: 'error',
  from: { path: `^src/modules/${escape(name)}/public(?:/|$)` },
  to: {
    path: `^src/modules/(?!${escape(name)}(?:/|$))[^/]+/public(?:/|$)`,
    dependencyTypesNot: ['type-only'],
  },
}));

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
      name: 'application-composition-public-only',
      severity: 'error',
      from: { path: '^src/application-composition(?:/|$)' },
      to: {
        path: `^src/(?:${allBusinessPaths})(?:/|$)`,
        pathNot: '^src/modules/[^/]+/public(?:/|$)',
      },
    },
    {
      name: 'application-composition-is-root-only',
      severity: 'error',
      from: { path: `^src/(?:platform|shared-kernel|${allBusinessPaths})(?:/|$)` },
      to: { path: '^src/application-composition(?:/|$)' },
    },
    ...publicCrossOwnerRules,
    {
      name: 'domain-no-nest-runtime',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain(?:/|$)' },
      to: { path: '^(?:node_modules/)?@nestjs/' },
    },
    {
      // Purity law: a domain may import generated Prisma enums and
      // Prisma.Decimal for types only, never the runtime client or the
      // persistence layer.
      name: 'domain-no-runtime-prisma',
      severity: 'error',
      from: { path: '^src/modules/[^/]+/domain(?:/|$)' },
      to: {
        path: '(?:^|/)node_modules/(?:@prisma/client|\\.prisma)(?:/|$)|^@prisma/client(?:/|$)|^src/platform/database(?:/|$)',
        dependencyTypesNot: ['type-only'],
      },
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
