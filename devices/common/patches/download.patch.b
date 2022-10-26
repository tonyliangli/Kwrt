--- a/scripts/download.pl
+++ b/scripts/download.pl
@@ -84,7 +84,7 @@ ($)
 	}
 
 	return $have_curl
-		? (qw(curl -f --connect-timeout 20 --retry 5 --location),
+		? (qw(curl -f --connect-timeout 5 --retry 3 -m 30 --location),
 			$check_certificate ? () : '--insecure',
 			shellwords($ENV{CURL_OPTIONS} || ''),
 			$url)