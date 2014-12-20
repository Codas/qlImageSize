//
//  GetMetadataForFile.m
//  qlImageSize
//
//  Created by @Nyx0uf on 20/12/14.
//  Copyright (c) 2014 Nyx0uf. All rights reserved.
//  www.cocoaintheshell.com
//


#import <CoreFoundation/CoreFoundation.h>
#import <CoreData/CoreData.h>
#import "decode.h"
#import "libbpg.h"


Boolean GetMetadataForFile(void* thisInterface, CFMutableDictionaryRef attributes, CFStringRef contentTypeUTI, CFStringRef pathToFile);


Boolean GetMetadataForFile(__unused void* thisInterface, CFMutableDictionaryRef attributes, __unused CFStringRef contentTypeUTI, CFStringRef pathToFile)
{
	@autoreleasepool
	{
		NSString* filepath = (__bridge NSString*)pathToFile;
		NSString* urlExtension = [[filepath pathExtension] lowercaseString];
		if ([urlExtension isEqualToString:@"webp"] || [urlExtension isEqualToString:@"pgm"] || [urlExtension isEqualToString:@"ppm"] || [urlExtension isEqualToString:@"pbm"] || [urlExtension isEqualToString:@"bpg"])
		{
			if ([urlExtension isEqualToString:@"webp"])
			{
				/* WebP */
				NSData* data = [[NSData alloc] initWithContentsOfFile:filepath];
				if (nil == data)
					return FALSE;

				const void* dataPtr = [data bytes];
				const size_t size = [data length];
				WebPDecoderConfig config;
				if (!WebPInitDecoderConfig(&config))
					return FALSE;
				if (WebPGetFeatures(dataPtr, size, &config.input) != VP8_STATUS_OK)
					return FALSE;
				if (WebPDecode(dataPtr, size, &config) != VP8_STATUS_OK)
					return FALSE;
				WebPFreeDecBuffer(&config.output);

				NSMutableDictionary* attrs = (__bridge NSMutableDictionary*)attributes;
				attrs[(NSString*)kMDItemPixelWidth] = @(config.input.width);
				attrs[(NSString*)kMDItemPixelHeight] = @(config.input.height);
				attrs[(NSString*)kMDItemPixelCount] = @(config.input.height * config.input.width);
				attrs[(NSString*)kMDItemHasAlphaChannel] = (!config.input.has_alpha) ? @NO : @YES;
				return TRUE;
			}
			else if ([urlExtension isEqualToString:@"bpg"])
			{
				/* bpg */
				// Open the file, get its size and read it
				FILE* f = fopen([filepath UTF8String], "rb");
				if (NULL == f)
					return FALSE;

				fseek(f, 0, SEEK_END);
				const size_t buf_len = (size_t)ftell(f);
				fseek(f, 0, SEEK_SET);

				uint8_t* buffer = (uint8_t*)malloc(buf_len);
				const size_t nb = fread(buffer, 1, buf_len, f);
				fclose(f);
				if (nb != buf_len)
				{
					free(buffer);
					return FALSE;
				}
			
				// Decode image
				BPGDecoderContext* img = bpg_decoder_open();
				int ret = bpg_decoder_decode(img, buffer, (int)buf_len);
				free(buffer);
				if (ret < 0)
				{
					bpg_decoder_close(img);
					return FALSE;
				}
			
				// Get image infos
				BPGImageInfo img_info_s, *img_info = &img_info_s;
				bpg_decoder_get_info(img, img_info);
				NSMutableDictionary* attrs = (__bridge NSMutableDictionary*)attributes;
				attrs[(NSString*)kMDItemPixelWidth] = @(img_info->width);
				attrs[(NSString*)kMDItemPixelHeight] = @(img_info->height);
				attrs[(NSString*)kMDItemPixelCount] = @(img_info->height * img_info->width);
				attrs[(NSString*)kMDItemBitsPerSample] = @(img_info->bit_depth);
				const BPGColorSpaceEnum cs = (BPGColorSpaceEnum)img_info->color_space;
				NSString* css = @"Undefined";
				switch (cs)
				{
					case BPG_CS_YCbCr:
						css = @"YCbCr";
						break;
					case BPG_CS_RGB:
						css = @"RGB";
						break;
					case BPG_CS_YCgCo:
						css = @"YCgCo";
						break;
					case BPG_CS_YCbCr_BT709:
						css = @"BT.709";
						break;
					case BPG_CS_YCbCr_BT2020:
						css = @"BT.2020";
						break;
					default:
						css = @"Undefined";
						break;
				}
				attrs[(NSString*)kMDItemColorSpace] = css;
				attrs[(NSString*)kMDItemHasAlphaChannel] = (!img_info->has_alpha) ? @NO : @YES;
				bpg_decoder_close(img);
			
				return TRUE;
			}
			else if ([urlExtension isEqualToString:@"pgm"] || [urlExtension isEqualToString:@"ppm"] || [urlExtension isEqualToString:@"pbm"])
			{
				// Grab image data
				NSData* data = [[NSData alloc] initWithContentsOfFile:filepath];
				if (nil == data)
					return FALSE;
				const uint8_t* bytes = (uint8_t*)[data bytes];
				if (NULL == bytes)
					return FALSE;
			
				// Identify type (handle binary only)
				if ((char)bytes[0] != 'P')
					return FALSE;
			
				// Get width
				size_t index = 3, i = 0;
				char ctmp[8] = {0x00};
				char c = 0x00;
				while ((c = (char)bytes[index++]) && (c != ' ' && c != '\r' && c != '\n' && c != '\t'))
					ctmp[i++] = c;
				size_t width = (size_t)atol(ctmp);
			
				// Get height
				i = 0;
				memset(ctmp, 0x00, 8);
				while ((c = (char)bytes[index++]) && (c != ' ' && c != '\r' && c != '\n' && c != '\t'))
					ctmp[i++] = c;
				size_t height = (size_t)atol(ctmp);

				NSMutableDictionary* attrs = (__bridge NSMutableDictionary*)attributes;
				attrs[(NSString*)kMDItemPixelWidth] = @(width);
				attrs[(NSString*)kMDItemPixelHeight] = @(height);
				attrs[(NSString*)kMDItemPixelCount] = @(height * width);
				attrs[(NSString*)kMDItemHasAlphaChannel] = @NO;
				return TRUE;
			}
			return FALSE;
		}
	}
    
	return TRUE;
}
