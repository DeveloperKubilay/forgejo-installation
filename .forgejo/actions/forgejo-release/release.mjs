import { execFileSync } from 'node:child_process';
import fs from 'node:fs';

function must(value, name) {
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function runGit(args) {
  return execFileSync('git', args, { encoding: 'utf8' }).trim();
}

function parseRepo(remoteUrl) {
  const cleaned = remoteUrl.replace(/\s+/g, '').replace(/\.git$/i, '');
  const m = cleaned.match(/[:/](?<owner>[^/]+)\/(?<repo>[^/]+)$/);
  if (!m?.groups?.owner || !m?.groups?.repo) {
    throw new Error(`Cannot parse owner/repo from remote: ${remoteUrl}`);
  }
  return { owner: m.groups.owner, repo: m.groups.repo };
}

async function apiJson(method, url, token, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `token ${token}`,
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  return { ok: res.ok, status: res.status, data };
}

async function apiUpload(url, token, filePath) {
  const buf = fs.readFileSync(filePath);
  const fd = new FormData();
  fd.append('attachment', new Blob([buf]), filePath.split(/[\\/]/).pop());

  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `token ${token}` },
    body: fd,
  });

  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  return { ok: res.ok, status: res.status, data };
}

const forgejoUrl = must(process.env.FORGEJO_URL, 'FORGEJO_URL');
const token = must(process.env.FORGEJO_TOKEN, 'FORGEJO_TOKEN');
const assetPath = must(process.env.INPUT_ASSET_PATH, 'asset_path');
const assetNameInput = process.env.INPUT_ASSET_NAME || '';

const tagInput = (process.env.INPUT_TAG || '').trim();
const tagFile = (process.env.INPUT_TAG_FILE || 'version.txt').trim();

let tag = tagInput;
if (!tag) {
  tag = fs.readFileSync(tagFile, 'utf8').trim();
}
if (!tag) throw new Error('Tag is empty');

const releaseName = (process.env.INPUT_RELEASE_NAME || '').trim() || tag;
const body = process.env.INPUT_BODY ?? '';

const remoteUrl = runGit(['remote', 'get-url', 'origin']);
const { owner, repo } = parseRepo(remoteUrl);

const apiBase = `${forgejoUrl.replace(/\/+$/, '')}/api/v1`;

const getUrl = `${apiBase}/repos/${owner}/${repo}/releases/tags/${encodeURIComponent(tag)}`;
const getResp = await apiJson('GET', getUrl, token);

let releaseId;
if (getResp.status === 200 && getResp.data?.id) {
  releaseId = getResp.data.id;
} else if (getResp.status === 404) {
  const createUrl = `${apiBase}/repos/${owner}/${repo}/releases`;
  const createResp = await apiJson('POST', createUrl, token, {
    tag_name: tag,
    name: releaseName,
    body,
    draft: false,
    prerelease: false,
  });
  if (!createResp.ok || !createResp.data?.id) {
    throw new Error(`Release create failed: ${createResp.status} ${JSON.stringify(createResp.data)}`);
  }
  releaseId = createResp.data.id;
} else {
  throw new Error(`Release lookup failed: ${getResp.status} ${JSON.stringify(getResp.data)}`);
}

const assetName = assetNameInput.trim() || assetPath.split(/[\\/]/).pop();
const uploadUrl = `${apiBase}/repos/${owner}/${repo}/releases/${releaseId}/assets?name=${encodeURIComponent(assetName)}`;
const upResp = await apiUpload(uploadUrl, token, assetPath);

if (!upResp.ok) {
  throw new Error(`Asset upload failed: ${upResp.status} ${JSON.stringify(upResp.data)}`);
}

console.log(`Release ${tag}: uploaded ${assetName}`);
