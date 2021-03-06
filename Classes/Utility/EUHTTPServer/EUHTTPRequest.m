//
//  EUHTTPRequest.m
//  EVEUniverse
//
//  Created by Shimanski on 8/30/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "EUHTTPRequest.h"
#import "NSString+EUHTTPServer.h"

@implementation EUHTTPRequest
@synthesize inputStream;
@synthesize message;
@synthesize delegate;

- (id)initWithInputStream:(NSInputStream *)readStream 
				 delegate:(id<EUHTTPRequestDelegate>) anObject {
	if (self = [super init]) {
		self.inputStream = readStream;
		message = CFHTTPMessageCreateEmpty(NULL, YES);
		self.delegate = anObject;
	}
	return self;
}

- (void) dealloc {
	[inputStream close];
	[inputStream release];
	[contentType release];
	[boundary release];
	if (message)
		CFRelease(message);
	
	[super dealloc];
}

- (void) run {
	if (self.inputStream) {
		self.inputStream.delegate = self;
		[self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[self.inputStream open];
	}
}

- (NSURL*) url {
	NSURL *url = (NSURL*) CFHTTPMessageCopyRequestURL(message);
	return [url autorelease];
}

- (NSString*) method {
	NSString* method = (NSString*) CFHTTPMessageCopyRequestMethod(message);
	return [method autorelease];
}

- (NSData*) body {
	NSData* data = (NSData*) CFHTTPMessageCopyBody(message);
	return [data autorelease];
}

- (NSDictionary*) arguments {
	if (!arguments) {
		arguments = [[NSMutableDictionary alloc] init];
		
		NSString* query = self.url.query;
		if (query) {
			[arguments addEntriesFromDictionary:[query httpGetArguments]];
		}
		
		NSString* contentTypeString = (NSString*) CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef) @"Content-Type");
		if ([self.contentType isEqualToString:@"application/x-www-form-urlencoded"]) {
			query = [[NSString alloc] initWithData:self.body encoding:NSUTF8StringEncoding];
			[arguments addEntriesFromDictionary:[query httpGetArguments]];
			[query release];
		}
		else if ([self.contentType isEqualToString:@"multipart/form-data"]) {
			if (self.boundary) {
				NSString* endMark = [NSString stringWithFormat:@"\r\n--%@--", self.boundary];
				NSString* delimiter = [NSString stringWithFormat:@"\r\n--%@", self.boundary];
				NSMutableString* body = [[NSMutableString alloc] initWithData:self.body encoding:NSUTF8StringEncoding];
				NSRange range = [body rangeOfString:endMark];
				if (range.location != NSNotFound) {
					range.length = body.length - range.location;
					[body replaceCharactersInRange:range withString:@""];
				}
				
				NSArray* parts = [body componentsSeparatedByString:delimiter];
				[body release];
				
				for (NSString* part in parts) {
					range = [part rangeOfString:@"\r\n\r\n"];
					if (range.location != NSNotFound) {
						NSString* headersString = [part substringToIndex:range.location];
						NSString* value = [part substringFromIndex:range.location + range.length];
						NSDictionary* headers = [headersString httpHeaders];
						NSString* contentDisposition = [headers valueForKey:@"Content-Disposition"];
						NSDictionary* valueFields = [contentDisposition httpHeaderValueFields];
						NSString* name = [valueFields valueForKey:@"name"];
						NSString* fileName = [valueFields valueForKey:@"filename"];
						if (name && value) {
							if (fileName) {
								NSDictionary* argument = [NSDictionary dictionaryWithObjectsAndKeys:fileName, @"fileName", value, @"value", nil];
								[arguments setValue:argument forKey:name];
							}
							else
								[arguments setValue:value forKey:name];
						}
					}
				}
			}
		}
		[contentTypeString release];
	}
	return arguments;
}

- (NSString*) contentType {
	if (!contentType) {
		NSString* contentTypeString = (NSString*) CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef) @"Content-Type");
		if ([contentTypeString rangeOfString:@"application/x-www-form-urlencoded"].location != NSNotFound)
			contentType = @"application/x-www-form-urlencoded";
		else if ([contentTypeString rangeOfString:@"multipart/form-data"].location != NSNotFound)
			contentType = @"multipart/form-data";
		else
			contentType = contentTypeString;
		[contentType retain];
		[contentTypeString release];
	}
	return contentType;
}

- (NSInteger) contentLength {
	if (contentLength == 0) {
		NSString* contentLengthString = (NSString*) CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef) @"Content-Length");
		contentLength = [contentLengthString integerValue];
		[contentLengthString release];
	}
	return contentLength;
}

- (NSString*) boundary {
	if (!boundary) {
		if ([self.contentType isEqualToString:@"multipart/form-data"]) {
			NSString* contentTypeString = (NSString*) CFHTTPMessageCopyHeaderFieldValue(message, (CFStringRef) @"Content-Type");
			NSDictionary* fields = [contentTypeString httpHeaderValueFields];
			boundary = [[fields valueForKey:@"boundary"] retain];
			[contentTypeString release];
		}
	}
	return boundary;
}

#pragma mark NSStreamDelegate

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	switch(eventCode) {
		case NSStreamEventHasBytesAvailable: {
			if (stream == self.inputStream) {
				UInt8 bytes[1024]; 
				NSInteger len = [self.inputStream read:bytes maxLength:1024];
				if (len > 0) {
					CFHTTPMessageAppendBytes(message, bytes, len);
					if (CFHTTPMessageIsHeaderComplete(message)) {
						if (self.contentLength > 0) {
							if (self.body.length >= self.contentLength) {
								[self.delegate httpRequest:self didCompleteWithError:nil];
								[self.inputStream close];
								self.inputStream = nil;
							}
						}
						else {
							[self.delegate httpRequest:self didCompleteWithError:nil];
							[self.inputStream close];
							self.inputStream = nil;
						}
					}
				}
			}
			break;
		}
		case NSStreamEventErrorOccurred: {
			[self.delegate httpRequest:self didCompleteWithError:[inputStream streamError]];
			[self.inputStream close];
			self.inputStream = nil;
			break;
		}
		case NSStreamEventEndEncountered: {
			[self.delegate httpRequest:self didCompleteWithError:nil];
			[self.inputStream close];
			self.inputStream = nil;
			break;
		}
		default:
			break;
	}
}

@end
