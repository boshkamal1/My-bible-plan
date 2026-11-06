'use strict';
// Read-only configuration inspection. Credentials stay inside the Firebase CLI.
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const cli = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(cli, 'auth'));
const {requireAuth} = require(path.join(cli, 'requireAuth'));
const rules = require(path.join(cli, 'gcp/rules'));
const {Client} = require(path.join(cli, 'apiv2'));
const project = 'bible-plan-boshkamal-20261101';
const write = (name, data) => fs.writeFileSync(path.join(__dirname, name), JSON.stringify(data, null, 2) + '\n');
async function inspect() {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Firebase CLI sign-in is required');
  await requireAuth({project, nonInteractive: true, user: account.user, tokens: account.tokens});
  const releases = await rules.listAllReleases(project);
  const release = releases.find(r => r.name === `projects/${project}/releases/cloud.firestore`);
  if (release) {
    const files = await rules.getRulesetContent(release.rulesetName);
    const content = files.map(f => f.content).join('\n');
    fs.writeFileSync(path.join(__dirname, 'live-firestore.rules'), content);
    const local = fs.readFileSync(path.join(root, 'flutter_app/firestore.rules'), 'utf8');
    const normalize = value => value.replace(/\r\n/g, '\n').trim();
    write('live-rules-metadata.json', {release: release.name, ruleset: release.rulesetName,
      updateTime: release.updateTime, matchesRepository: normalize(content) === normalize(local),
      sha256: crypto.createHash('sha256').update(content).digest('hex')});
    console.log('Live Firestore rules downloaded; repository match:', normalize(content) === normalize(local));
  }
  async function getConfig(origin, version, endpoint, pick, filename) {
    try {
      const response = await new Client({urlPrefix: origin, apiVersion: version}).get(endpoint, {skipLog:{resBody:true}});
      write(filename, {status: response.status, ...pick(response.body)});
      console.log(filename, 'read successfully');
    } catch (error) {
      write(filename, {status: error.status || error.context?.response?.statusCode || 'unavailable',
        inspected: false});
      console.log(filename, 'unavailable; no settings changed');
    }
  }
  await getConfig('https://identitytoolkit.googleapis.com', 'v2', `/projects/${project}/config`, body => ({
    authorizedDomains: body.authorizedDomains,
    signIn: {
      anonymousEnabled: body.signIn?.anonymous?.enabled,
      emailEnabled: body.signIn?.email?.enabled,
      passwordRequired: body.signIn?.email?.passwordRequired,
      phoneEnabled: body.signIn?.phoneNumber?.enabled,
      allowDuplicateEmails: body.signIn?.allowDuplicateEmails,
    },
    passwordPolicyConfig: body.passwordPolicyConfig,
    emailPrivacyConfig: body.emailPrivacyConfig,
    recaptchaConfig: body.recaptchaConfig,
  }), 'auth-config-summary.json');
  await getConfig('https://firebaseappcheck.googleapis.com', 'v1', '/projects/765669491597/services', body => ({
    services: body.services?.map(s => ({name:s.name, enforcementMode:s.enforcementMode})),
  }), 'app-check-summary.json');
  await getConfig('https://firebaseappcheck.googleapis.com', 'v1', '/projects/765669491597/services/firestore.googleapis.com', body => ({
    name: body.name, enforcementMode: body.enforcementMode,
  }), 'app-check-firestore.json');
}
inspect().catch(() => {console.error('Read-only live inspection failed; no settings changed.');process.exitCode=1;});
