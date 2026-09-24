import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import ts from 'typescript';

// The live authorization re-check used to be part of the SQL statement that
// returned the data (`weddingPlan: { is: livePlanAuthorizationWhere(...) }`),
// so a committed revocation could never pass. Owners now evaluate the
// predicate (`liveAuthorizationFilter`) in its own statement, so the filter
// and the read it guards must share one snapshot: the filter runs on the
// client of a RepeatableRead or Serializable transaction, and that client is
// what the guarded read uses. A helper may take the client from its caller;
// then every caller must pass such a client.

const srcRoot = path.resolve(__dirname, '../src');

function tsFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const full = path.join(dir, name);
    if (statSync(full).isDirectory()) return tsFiles(full);
    return name.endsWith('.ts') ? [full] : [];
  });
}

const sources = tsFiles(srcRoot).map((file) => ts.createSourceFile(
  file,
  readFileSync(file, 'utf8'),
  ts.ScriptTarget.Latest,
  true,
));

type FunctionLike = ts.ArrowFunction | ts.FunctionExpression | ts.FunctionDeclaration | ts.MethodDeclaration;

function isFunctionLike(node: ts.Node): node is FunctionLike {
  return ts.isArrowFunction(node) || ts.isFunctionExpression(node)
    || ts.isFunctionDeclaration(node) || ts.isMethodDeclaration(node);
}

function calleeName(call: ts.CallExpression): string | null {
  const expression = call.expression;
  if (ts.isIdentifier(expression)) return expression.text;
  if (ts.isPropertyAccessExpression(expression)) return expression.name.text;
  return null;
}

/** The transaction call a function literal is the operation callback of, when it is a snapshot transaction. */
function snapshotTransaction(fn: FunctionLike): boolean {
  const call = fn.parent;
  if (!call || !ts.isCallExpression(call) || call.arguments[1] !== fn) return false;
  const name = calleeName(call);
  if (name === 'runSerializableTransaction') return true;
  if (name !== 'runRetryableTransaction') return false;
  const options = call.arguments[2];
  return Boolean(options && /isolationLevel:\s*Prisma\.TransactionIsolationLevel\.(RepeatableRead|Serializable)/u
    .test(options.getText()));
}

/** Where the identifier `name` is declared as a parameter of an enclosing function. */
function declaringFunction(node: ts.Node, name: string): { fn: FunctionLike; index: number } | null {
  for (let current: ts.Node | undefined = node.parent; current; current = current.parent) {
    if (isFunctionLike(current)) {
      const index = current.parameters.findIndex((parameter) => (
        ts.isIdentifier(parameter.name) && parameter.name.text === name
      ));
      if (index >= 0) return { fn: current, index };
    }
  }
  return null;
}

function functionName(fn: FunctionLike): string | null {
  if ((ts.isFunctionDeclaration(fn) || ts.isMethodDeclaration(fn)) && fn.name && ts.isIdentifier(fn.name)) {
    return fn.name.text;
  }
  return null;
}

function where(node: ts.Node): string {
  const file = node.getSourceFile();
  const { line } = file.getLineAndCharacterOfPosition(node.getStart());
  return `${path.relative(srcRoot, file.fileName).replace(/\\/gu, '/')}:${line + 1}`;
}

/** Whether the client expression is a snapshot transaction's client, directly or through every caller of a helper. */
function snapshotClient(argument: ts.Expression, depth = 0): string | null {
  if (!ts.isIdentifier(argument)) return `${where(argument)} passes ${argument.getText()}, not a transaction client`;
  const declared = declaringFunction(argument, argument.text);
  if (!declared) return `${where(argument)} passes ${argument.text}, which is not a parameter`;
  if (snapshotTransaction(declared.fn)) return null;
  const name = functionName(declared.fn);
  if (!name || depth > 2) return `${where(argument)} passes ${argument.text} from outside a snapshot transaction`;
  const calls: ts.CallExpression[] = [];
  for (const source of sources) {
    const visit = (node: ts.Node) => {
      if (ts.isCallExpression(node) && calleeName(node) === name) calls.push(node);
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
  if (calls.length === 0) return `${where(argument)}: ${name} has no caller`;
  for (const call of calls) {
    const passed = call.arguments[declared.index];
    const problem = passed ? snapshotClient(passed, depth + 1) : `${where(call)} passes no client`;
    if (problem) return problem;
  }
  return null;
}

test('every live authorization filter shares a snapshot with the read it guards', () => {
  const problems: string[] = [];
  let filters = 0;
  for (const source of sources) {
    if (source.fileName.replace(/\\/gu, '/').endsWith('/collaboration/internal/permission.service.ts')) continue;
    const visit = (node: ts.Node) => {
      if (ts.isCallExpression(node) && calleeName(node) === 'liveAuthorizationFilter' && node.arguments[0]) {
        filters += 1;
        const problem = snapshotClient(node.arguments[0]);
        if (problem) problems.push(problem);
      }
      ts.forEachChild(node, visit);
    };
    visit(source);
  }
  assert.ok(filters >= 19, `expected every live filter call, found ${filters}`);
  assert.deepEqual(problems, []);
});
