const $ = id => document.getElementById(id);
let target;
async function update(method = 'status') {
  $('site').disabled = $('page').disabled = true;
  try {
    if (!target) {
      const [tab] = await chrome.tabs.query({active:true,currentWindow:true});
      target = tab?.url;
      const {lastResult} = await chrome.storage.session.get('lastResult');
      if (lastResult?.showTarget && Date.now()-lastResult.time<15000) {
        target = lastResult.url;
        await chrome.storage.session.remove('lastResult');
      }
    }
    const url = new URL(target);
    if (!['http:','https:'].includes(url.protocol) || url.username || url.password) throw Error('Ouvrez une page web pour l’ajouter à Squeak.');
    $('domain').textContent = url.host;
    $('url').textContent = target;
    $('status').textContent = method === 'status' ? 'Vérification…' : 'Ajout dans Squeak…';
    const result = await chrome.runtime.sendMessage({method,url:target});
    if (!result?.ok) throw Error(result?.error || 'Connexion à Squeak indisponible.');
    $('status').textContent = result.covered ? '✓ Déjà intégré à SQUEAK' : 'Ce site n’est pas encore intégré.';
    $('site').textContent = result.siteAdded ? '✓ Site déjà ajouté' : 'Ajouter ce site';
    $('page').textContent = result.pageAdded ? '✓ Page déjà ajoutée' : 'Ajouter cette page uniquement';
    $('site').disabled = result.siteAdded;
    $('page').disabled = result.pageAdded;
    $('detail').textContent = result.covered && !result.enabled ? 'Cet élément est décoché dans Squeak. Activez-le dans l’application pour autoriser sa fermeture.' : 'Le site inclut ses pages. L’option page conserve uniquement cette adresse exacte.';
  } catch (error) { $('status').textContent = error.message; }
}
$('site').addEventListener('click', () => update('add-site'));
$('page').addEventListener('click', () => update('add-page'));
$('retry').addEventListener('click', () => {target=null; void update();});
chrome.storage.local.get('tabContext').then(({tabContext}) => {
  $('placement').textContent = tabContext ? 'Disponible aussi au clic droit sur un onglet, une page ou un lien.' : 'Disponible au clic droit dans une page ou sur un lien. Ce navigateur ne propose pas ce menu sur les onglets.';
});
void update();
