push:
	docker build --platform linux/amd64 -t pyama/gmail-signature:latest .
	docker push pyama/gmail-signature:latest
