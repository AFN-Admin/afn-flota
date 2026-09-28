const CACHE='afn-flota-pwa-v56';
const STATIC=['./','./index.html','./manifest.webmanifest','./afn-icon.svg','./pwa-icon-192.png','./pwa-icon-512.png','./afn-flota-logo.png','./afn-flota-dashboard-logo.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(STATIC)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{if(event.request.method!=='GET')return;event.respondWith(fetch(event.request).then(response=>{const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy));return response;}).catch(()=>caches.match(event.request).then(hit=>hit||caches.match('./index.html'))));});
