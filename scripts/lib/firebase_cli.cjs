'use strict';
const path=require('node:path');
const root=path.join(process.env.APPDATA,'npm/node_modules/firebase-tools/lib');
const auth=require(path.join(root,'auth'));
const {requireAuth}=require(path.join(root,'requireAuth'));
const {Client}=require(path.join(root,'apiv2'));
const project='bible-plan-boshkamal-20261101';
async function clients() {
  const account=auth.getGlobalDefaultAccount();
  if(!account)throw Error('Firebase CLI sign-in is required');
  await requireAuth({project,nonInteractive:true,user:account.user,tokens:account.tokens});
  return {project,firestore:new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'}),
    auth:new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1'}),
    authConfig:new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v2'}),
    appCheck:new Client({urlPrefix:'https://firebaseappcheck.googleapis.com',apiVersion:'v1'}),
    rules:require(path.join(root,'gcp/rules'))};
}
// firebase-tools mutates request options; never reuse an authenticated options object.
const quiet=()=>({skipLog:{body:true,resBody:true}});
module.exports={clients,project,quiet};
