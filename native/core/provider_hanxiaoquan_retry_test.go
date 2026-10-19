package core

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/url"
	"testing"
)

func TestHanxiaoquanAutoModePrefersDirect(t *testing.T) {
	router := &proxyRouter{mode: "auto", system: nativeSystemProxy{HTTPS: "http://127.0.0.1:9999"}, systemOverride: true}
	calls := 0
	downloader := sourceFixtureDownloader(t, func(request *http.Request) (*http.Response, error) {
		calls++
		proxy, err := router.proxy(request)
		if err != nil {
			return nil, err
		}
		if proxy != nil {
			return nil, io.EOF
		}
		return sourceFixtureResponse(request, 200, "fixture"), nil
	})
	downloader.proxyRouter = router
	body, err := downloader.hanxiaoquanGet(context.Background(), "/hxq/1.html")
	if err != nil || body != "fixture" || calls != 1 {
		t.Fatalf("auto route: body=%q calls=%d err=%v", body, calls, err)
	}
	router.mode = "manual"
	router.manual, _ = url.Parse("http://127.0.0.1:9999")
	_, err = downloader.hanxiaoquanGet(context.Background(), "/hxq/1.html")
	if !errors.Is(err, io.EOF) || calls != 2 {
		t.Fatalf("manual proxy was bypassed: calls=%d err=%v", calls, err)
	}
}

func TestHanxiaoquanAutoModeFallsBackToSystemProxy(t *testing.T) {
	router := &proxyRouter{mode: "auto", system: nativeSystemProxy{HTTPS: "http://127.0.0.1:9999"}, systemOverride: true}
	calls := 0
	downloader := sourceFixtureDownloader(t, func(request *http.Request) (*http.Response, error) {
		calls++
		proxy, err := router.proxy(request)
		if err != nil {
			return nil, err
		}
		if proxy == nil {
			return nil, io.EOF
		}
		return sourceFixtureResponse(request, 200, "fixture"), nil
	})
	downloader.proxyRouter = router
	body, err := downloader.hanxiaoquanGet(context.Background(), "/hxq/1.html")
	if err != nil || body != "fixture" || calls != 2 {
		t.Fatalf("system proxy fallback: body=%q calls=%d err=%v", body, calls, err)
	}
}

func TestHanxiaoquanMediaRetryKeepsDirectRoute(t *testing.T) {
	router := &proxyRouter{mode: "auto", system: nativeSystemProxy{HTTPS: "http://127.0.0.1:9999"}, systemOverride: true}
	playlistCalls := 0
	directPageCalls := 0
	downloader := sourceFixtureDownloader(t, func(request *http.Request) (*http.Response, error) {
		switch request.URL.Path {
		case "/play/4597-1-1.html":
			proxy, _ := router.proxy(request)
			if proxy == nil {
				directPageCalls++
			}
			return sourceFixtureResponse(request, 200, `<script>var now="https://v.lfthirtytwo.com/index.m3u8";</script>`), nil
		case "/index.m3u8":
			playlistCalls++
			proxy, err := router.proxy(request)
			if err != nil {
				return nil, err
			}
			if proxy != nil || playlistCalls <= 2 {
				return sourceFixtureResponse(request, 404, "missing"), nil
			}
			return sourceFixtureResponse(request, 200, "#EXTM3U\n#EXTINF:4,\nseg.ts\n#EXT-X-ENDLIST"), nil
		default:
			t.Errorf("unexpected request: %s", request.URL.Path)
			return nil, io.EOF
		}
	})
	downloader.proxyRouter = router
	playURL := "https://www.jennyhow.com/play/4597-1-1.html"
	media, err := downloader.resolveHanxiaoquanMedia(context.Background(), Task{
		DramaID: "hanxiaoquan:4597",
		Chapter: Chapter{ID: providerChapterID(sourceHanxiaoquan, "4597", playURL), Source: sourceHanxiaoquan},
	})
	if err != nil || playlistCalls != 3 || directPageCalls != 2 || media.credentials == nil {
		t.Fatalf("media fallback: playlistCalls=%d directPageCalls=%d credentials=%v err=%v", playlistCalls, directPageCalls, media.credentials, err)
	}
	request, _ := http.NewRequestWithContext(providerMediaContext(context.Background(), media.credentials), http.MethodGet, "https://v.lfthirtytwo.com/seg.ts", nil)
	proxy, err := router.proxy(request)
	if err != nil || proxy != nil {
		t.Fatalf("media segment did not keep direct route: proxy=%v err=%v", proxy, err)
	}
}

func TestHanxiaoquanMediaFallsBackToSystemProxy(t *testing.T) {
	router := &proxyRouter{mode: "auto", system: nativeSystemProxy{HTTPS: "http://127.0.0.1:9999"}, systemOverride: true}
	direct, proxied := 0, 0
	downloader := sourceFixtureDownloader(t, func(request *http.Request) (*http.Response, error) {
		if request.URL.Path == "/play/4597-1-1.html" {
			return sourceFixtureResponse(request, 200, `<script>var now="https://v.lfthirtytwo.com/index.m3u8";</script>`), nil
		}
		proxy, err := router.proxy(request)
		if err != nil {
			return nil, err
		}
		if proxy == nil {
			direct++
			return nil, io.EOF
		}
		proxied++
		return sourceFixtureResponse(request, 200, "#EXTM3U\n#EXTINF:4,\nseg.ts\n#EXT-X-ENDLIST"), nil
	})
	downloader.proxyRouter = router
	playURL := "https://www.jennyhow.com/play/4597-1-1.html"
	media, err := downloader.resolveHanxiaoquanMedia(context.Background(), Task{
		DramaID: "hanxiaoquan:4597",
		Chapter: Chapter{ID: providerChapterID(sourceHanxiaoquan, "4597", playURL), Source: sourceHanxiaoquan},
	})
	if err != nil || direct != 2 || proxied != 1 || media.credentials != nil {
		t.Fatalf("media proxy fallback: direct=%d proxied=%d credentials=%v err=%v", direct, proxied, media.credentials, err)
	}
}
