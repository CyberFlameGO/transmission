// This file Copyright © 2009-2022 Transmission authors and contributors.
// It may be used under the MIT (SPDX: MIT) license.
// License text can be found in the licenses/ folder.

#import "TrackerNode.h"
#import "NSApplicationAdditions.h"
#import "NSStringAdditions.h"

@implementation TrackerNode
{
    tr_tracker_view fStat;
}

- (instancetype)initWithTrackerView:(tr_tracker_view const*)stat torrent:(Torrent*)torrent
{
    if ((self = [super init]))
    {
        fStat = *stat;
        _torrent = torrent; //weak reference
    }

    return self;
}

- (NSString*)description
{
    return [@"Tracker: " stringByAppendingString:self.fullAnnounceAddress];
}

- (id)copyWithZone:(NSZone*)zone
{
    //this object is essentially immutable after initial setup
    return self;
}

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:[self class]])
    {
        return NO;
    }

    auto other = static_cast<decltype(self)>(object);
    if (self.torrent != other.torrent)
    {
        return NO;
    }

    return self.tier == other.tier && [self.fullAnnounceAddress isEqualToString:other.fullAnnounceAddress];
}

- (NSString*)host
{
    return @(fStat.host);
}

- (NSString*)fullAnnounceAddress
{
    return @(fStat.announce);
}

- (NSInteger)tier
{
    return fStat.tier;
}

- (NSUInteger)identifier
{
    return fStat.id;
}

- (NSInteger)totalSeeders
{
    return fStat.seederCount;
}

- (NSInteger)totalLeechers
{
    return fStat.leecherCount;
}

- (NSInteger)totalDownloaded
{
    return fStat.downloadCount;
}

- (NSString*)lastAnnounceStatusString
{
    NSString* dateString;
    if (fStat.hasAnnounced)
    {
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterFullStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        dateFormatter.doesRelativeDateFormatting = YES;

        dateString = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:fStat.lastAnnounceTime]];
    }
    else
    {
        dateString = NSLocalizedString(@"N/A", "Tracker last announce");
    }

    NSString* baseString;
    if (fStat.hasAnnounced && fStat.lastAnnounceTimedOut)
    {
        baseString = [NSLocalizedString(@"Announce timed out", "Tracker last announce") stringByAppendingFormat:@": %@", dateString];
    }
    else if (fStat.hasAnnounced && !fStat.lastAnnounceSucceeded)
    {
        baseString = NSLocalizedString(@"Announce error", "Tracker last announce");

        NSString* errorString = @(fStat.lastAnnounceResult);
        if ([errorString isEqualToString:@""])
        {
            baseString = [baseString stringByAppendingFormat:@": %@", dateString];
        }
        else
        {
            baseString = [baseString stringByAppendingFormat:@": %@ - %@", errorString, dateString];
        }
    }
    else
    {
        baseString = [NSLocalizedString(@"Last Announce", "Tracker last announce") stringByAppendingFormat:@": %@", dateString];
        if (fStat.hasAnnounced && fStat.lastAnnounceSucceeded && fStat.lastAnnouncePeerCount > 0)
        {
            NSString* peerString;
            if (fStat.lastAnnouncePeerCount == 1)
            {
                peerString = NSLocalizedString(@"got 1 peer", "Tracker last announce");
            }
            else
            {
                peerString = [NSString stringWithFormat:NSLocalizedString(@"got %d peers", "Tracker last announce"), fStat.lastAnnouncePeerCount];
            }
            baseString = [baseString stringByAppendingFormat:@" (%@)", peerString];
        }
    }

    return baseString;
}

- (NSString*)nextAnnounceStatusString
{
    switch (fStat.announceState)
    {
    case TR_TRACKER_ACTIVE:
        return [NSLocalizedString(@"Announce in progress", "Tracker next announce") stringByAppendingEllipsis];

    case TR_TRACKER_WAITING:
        {
            NSTimeInterval const nextAnnounceTimeLeft = fStat.nextAnnounceTime - [NSDate date].timeIntervalSince1970;

            static NSDateComponentsFormatter* formatter;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                formatter = [NSDateComponentsFormatter new];
                formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
                formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropLeading;
                formatter.collapsesLargestUnit = YES;
            });

            NSString* timeString = [formatter stringFromTimeInterval:nextAnnounceTimeLeft];
            return [NSString stringWithFormat:NSLocalizedString(@"Next announce in %@", "Tracker next announce"), timeString];
        }
    case TR_TRACKER_QUEUED:
        return [NSLocalizedString(@"Announce is queued", "Tracker next announce") stringByAppendingEllipsis];

    case TR_TRACKER_INACTIVE:
        return fStat.isBackup ? NSLocalizedString(@"Tracker will be used as a backup", "Tracker next announce") :
                                NSLocalizedString(@"Announce not scheduled", "Tracker next announce");

    default:
        NSAssert1(NO, @"unknown announce state: %d", fStat.announceState);
        return nil;
    }
}

- (NSString*)lastScrapeStatusString
{
    NSString* dateString;
    if (fStat.hasScraped)
    {
        NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = NSDateFormatterFullStyle;
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
        dateFormatter.doesRelativeDateFormatting = YES;

        dateString = [dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:fStat.lastScrapeTime]];
    }
    else
    {
        dateString = NSLocalizedString(@"N/A", "Tracker last scrape");
    }

    NSString* baseString;
    if (fStat.hasScraped && fStat.lastScrapeTimedOut)
    {
        baseString = [NSLocalizedString(@"Scrape timed out", "Tracker last scrape") stringByAppendingFormat:@": %@", dateString];
    }
    else if (fStat.hasScraped && !fStat.lastScrapeSucceeded)
    {
        baseString = NSLocalizedString(@"Scrape error", "Tracker last scrape");

        NSString* errorString = @(fStat.lastScrapeResult);
        if ([errorString isEqualToString:@""])
        {
            baseString = [baseString stringByAppendingFormat:@": %@", dateString];
        }
        else
        {
            baseString = [baseString stringByAppendingFormat:@": %@ - %@", errorString, dateString];
        }
    }
    else
    {
        baseString = [NSLocalizedString(@"Last Scrape", "Tracker last scrape") stringByAppendingFormat:@": %@", dateString];
    }

    return baseString;
}

@end