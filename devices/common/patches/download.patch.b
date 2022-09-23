--- a/scripts/download.pl
+++ b/scripts/download.pl
@@ -82,7 +82,7 @@ ($)
 	}
 
 	return $have_curl
-		? (qw(curl -f --connect-timeout 20 --retry 5 --location --insecure), shellwords($ENV{CURL_OPTIONS} || ''), $url)
+		? (qw(curl -f --connect-timeout 5 --retry 3 -m 30 --location --insecure), shellwords($ENV{CURL_OPTIONS} || ''), $url)
		: (qw(wget --tries=5 --timeout=20 --no-check-certificate --output-document=-), shellwords($ENV{WGET_OPTIONS} || ''), $url)
	;
}