const HOST = 'com.squeak.desktop';
const MENU = 'squeak';
export function supportedUrl(value) {
  try {
    const url = new URL(value);
    return ['https:', 'http:'].includes(url.protocol) && !url.username && !url.password ? url.href : null;
  } catch { return null; }
}
function createMenu(item) {
  return new Promise((resolve, reject) => {
    try { chrome.contextMenus.create(item, () => {
      const error = chrome.runtime.lastError;
      error ? reject(new Error(error.message)) : resolve();
    }); } catch (error) { reject(error); }
  });
}
export async function installMenus() {
  await chrome.contextMenus.removeAll();
  let tabContext = true;
  try {
    await createMenu({id: MENU, title: 'Intégrer à SQUEAK', contexts: ['tab','page','link']});
  } catch {
    tabContext = false;
    await createMenu({id: MENU, title: 'Intégrer à SQUEAK', contexts: ['page','link']});
  }
  const contexts = tabContext ? ['tab','page','link'] : ['page','link'];
  for (const [id, title] of [['site','Ajouter ce site'],['page','Ajouter cette page uniquement'],['status','Vérifier si déjà intégré']]) {
    await createMenu({id: `${MENU}-${id}`, parentId: MENU, title, contexts});
  }
  await chrome.storage.local.set({tabContext});
}
export async function requestNative(method, value) {
  const url = supportedUrl(value);
  if (!url) throw new Error('Choisissez une page web HTTP ou HTTPS.');
  let result;
  try { result = await chrome.runtime.sendNativeMessage(HOST, {method, url}); }
  catch { throw new Error('Liaison avec Squeak indisponible. Relancez Installer Squeak.command sur votre Mac.'); }
  if (!result?.ok) throw new Error(result?.error || 'Squeak n’a pas confirmé l’opération.');
  return result;
}
export async function showBadge(tabId, status, error = '') {
  if (!Number.isInteger(tabId)) return;
  await chrome.action.setBadgeText({tabId, text: error ? '!' : status?.covered ? '✓' : ''});
  await chrome.action.setBadgeBackgroundColor({tabId, color: error ? '#AC473D' : '#99702F'});
  await chrome.action.setTitle({tabId, title: error || (status?.covered ? 'Déjà intégré à SQUEAK ✓' : 'Intégrer à SQUEAK')});
}
async function refreshTab(tabId) {
  try {
    const tab = await chrome.tabs.get(tabId);
    if (!supportedUrl(tab.url)) { await showBadge(tabId, null); return; }
    const status = await requestNative('status', tab.url);
    // A navigation during the request must not give the new page an old status.
    const current = await chrome.tabs.get(tabId);
    if (current.url === tab.url) await showBadge(tabId, status);
  } catch { /* No notification for background status failures. */ }
}
chrome.runtime.onInstalled.addListener(() => installMenus().catch(console.error));
chrome.runtime.onStartup.addListener(() => installMenus().catch(console.error));
chrome.tabs.onActivated.addListener(({tabId}) => { void refreshTab(tabId); });
chrome.tabs.onUpdated.addListener((tabId, change, tab) => {
  if (tab.active && (change.url || change.status === 'complete')) void refreshTab(tabId);
});
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  const method = { 'squeak-site':'add-site', 'squeak-page':'add-page', 'squeak-status':'status' }[info.menuItemId];
  if (!method || !tab) return;
  // The clicked background tab or link is authoritative, never the active tab.
  const target = info.linkUrl || info.pageUrl || tab.url;
  try {
    const result = await requestNative(method, target);
    await chrome.storage.session.set({lastResult: {url:target, result, time:Date.now(), showTarget:method==='status'}});
    if (!info.linkUrl) await showBadge(tab.id, result);
    if (method === 'status') await chrome.action.openPopup({windowId:tab.windowId});
  } catch (error) {
    await chrome.storage.session.set({lastResult: {url:target, error:error.message, time:Date.now()}});
    await showBadge(tab.id, null, error.message);
  }
});
chrome.runtime.onMessage.addListener((message, sender, respond) => {
  if (sender.id !== chrome.runtime.id || !['status','add-site','add-page'].includes(message?.method)) return;
  requestNative(message.method, message.url)
    .then(result => respond(result))
    .catch(error => respond({ok:false, error:error.message}));
  return true;
});
