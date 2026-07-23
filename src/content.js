
//appends our injections to the page
//inject.js depends on functions defined by twitter_video_downloader.js, so the
//downloader must execute first. Setting async=false preserves execution order
//for dynamically inserted scripts while still letting both load in parallel.
//Previously these were chained via onload, which added an extra round-trip and
//widened the race window in which Twitter could fire (and we could miss) the
//tweet request before the interceptor was installed.
const root = document.head || document.documentElement;

const downloaderScript = document.createElement('script');
downloaderScript.src = chrome.runtime.getURL('twitter_video_downloader.js');
downloaderScript.async = false;
downloaderScript.onload = () => downloaderScript.remove();

const interceptorScript = document.createElement('script');
interceptorScript.src = chrome.runtime.getURL('inject.js');
interceptorScript.async = false;
interceptorScript.onload = () => interceptorScript.remove();

root.appendChild(downloaderScript);
root.appendChild(interceptorScript);



//receive messages from the injected script and send them to our listeners
window.addEventListener('message', (event) => {

  //making sure we're processing only our extension and tab events
  if (event.source !== window) return;
  if (event.data?.source === 'rectifying@gmail.com' && event.data.type === 'UPDATE_SESSION_DATA') {

    //pass the events further to the main code outside
    chrome.runtime.sendMessage({
      type: 'UPDATE_SESSION_DATA',
      data: event.data.data
    });
  }
});