# مزودو الترفيه والتصوير والزينة والتجميل في الأعراس اليمنية (Yemeni wedding entertainment, photography, decoration and beauty vendors)

> Research date: 2026-10-19. Method: web search (Arabic and English) and page fetches, about 20 tool calls. The public web has little structured material on this. Most vendor presence is on Facebook, TikTok and WhatsApp, which search engines index poorly. Many findings below are thin or come from discovery pages. Where a claim has no source, it is in "Inferences" or "Gaps", not "Cited Findings". **Treat the inferences as hypotheses to check in interviews with vendors.**

## 1. Context that cuts across all types: the wedding schedule, and where each provider fits

### Takeaway
A Sana'a wedding is a sequence of separate events over several days, with men and women apart. Each provider is booked for one specific event or time slot (henna night, برع, مقيل, زفة, the women's party), not for "the wedding" as a whole. The data model should be event/slot based, with a gender flag on each event.

### Cited Findings
- Sana'a men's sequence (article dated 17 Mar 2021) — [المشاهد نت](https://almushahid.net/75127/):
  - **Wednesday, ليلة الحناء:** henna night with chants and music.
  - **Thursday morning:** songs over loudspeakers, then **البرع** with جنابي (daggers) to drums called «المرافع».
  - **Lunch**, then **المقيل** (afternoon qat session). It opens with «زفة الديوان», led by a **منشد** reciting devotional verses. **Singers then play Sanaani songs on the oud until sunset** ("الساعة السليمانية").
  - **Night:** the final **زفة** with Sanaani anashid.
- Same source, the women's week (7 days): التوديع، الحمام، الذبال (a popular singer drums on a plate and spoon, صحن وملعقة)، **النقش** (henna and dye, done by the bride's mother and sisters in the traditional form)، **الحفلة** (the women's party in a dedicated hall)، النسمة، الدخلة — [المشاهد نت](https://almushahid.net/75127/)
- Sana'a nashshad (wedding chanters) "are in great demand and very well paid; they go from one wedding to another" — [arabosounds, Sacred songs from Sanaa](http://www.arabosounds.com/en/sacred-songs-from-sanaa/) (date unknown; English search snippet, page not fetched).
- One account of Sana'a weddings says there are no professional dancers at the women's party, only a small all-female group, usually **a singer, an oud player and a percussionist** — [Gilded Serpent, Dancing in Yemen pt 2](http://www.gildedserpent.com/articles13/dancingyemen2jalilah.htm) (search snippet only; the page was blocked when fetched; date unknown, probably before 2015).
- Ordinary families in Yemen use dedicated women's halls (صالات نسائية), and both men's and women's halls exist — [النداء](https://www.alndaa.net/posts/100603); [الراي](https://www.alraimedia.com/article/801562/)

### Inferences
- One منشد can perform at more than one wedding on the same day, moving between them ("go from one wedding to another"). Capacity for this type should therefore be counted per time slot (for example a زفة slot), not per night. **Probable but unconfirmed.**
- Singers are tied to the مقيل slot (roughly early afternoon to sunset). On the same day they can also take an evening سمرة. So the unit is a "period" (فترة), not a "night".

### Gaps
- No sources found on the schedule in Aden, Hadramout or Taiz. The schedule there probably differs, for example Aden's evening parties and Hadramout's زربادي, but nothing was documented.

## 2. One person or a business with several teams (capacity)

### Takeaway
No source documents this directly. The available evidence suggests a mix. Individual performers (the oud singer, the women's singer) take one booking per slot. Kosha and coordination companies and some studios work as businesses that can serve several weddings at once.

### Cited Findings
- The women's party group is small (a singer, an oud player and a percussionist), which means a "group" is a unit made of several people — [Gilded Serpent](http://www.gildedserpent.com/articles13/dancingyemen2jalilah.htm) (snippet)
- Event-company offices exist that list themselves as «مكتب حفلة متعهد حفلات | كوش أعراس» (Sana'a, al-Wahda district) — [مناسبات يمنية](https://monasabatyemeniah.com/services/koshah)
- A commercial directory claims "more than 1,000 koshas and more than 300 halls" in Sana'a — [حلم العاصمة](https://www.halmalasima.com/) (marketing claim, not verified).
- Women photographers in Aden publish wedding coverage from several named halls, e.g. «قاعة القصر الملكي» and «قاعة التاج الذهبية», under tags such as #مصورات_عدن — [TikTok discover](https://www.tiktok.com/discover/%D9%85%D9%86%D8%B3%D9%82%D9%87-%D8%A7%D8%B9%D8%B1%D8%A7%D8%B3-%D9%81%D9%8A-%D8%B9%D8%AF%D9%86) (discovery page; low reliability).

### Inferences
- Suggested capacity per provider type for the data model (**assumptions, to be checked in field interviews**):

| Type | Likely capacity | Unit |
|---|---|---|
| الفنان (oud singer) | 1 | per period (مقيل / سمرة) |
| المنشد / فرقة الزفة | 1, possibly 2+ short slots | per زفة slot |
| فرق المزمار والطبل / البرع | Varies; a group leader may run several groups | per period |
| الفنانة / فرقة النساء | 1 group | per night |
| المصورة | 1 (individual) or several teams (studio) | per night |
| استوديو تصوير | N teams | per night |
| الكوش والمنسقات | N (setup capacity limited by staff and stock) | per day, plus setup and teardown time |
| المنقشة | Several brides a day at home or in a salon | per appointment |
| الكوافير / الصالون | Several (number of stylists) | per appointment |
| الألعاب النارية | Usually a retail sale, not a booked service | per order |

- So the app needs a `capacity` field on each provider, with a default of 1 and an option to define "teams" (فرق/طواقم) that are booked separately.

### Gaps
- No interview or article found that confirms Yemeni studios run several teams on the same night, or how برع groups are split up.

## 3. Booking, how far ahead, peak seasons, deposit, contract, cancellation

### Takeaway
There are almost no published sources on deposits and cancellation for these providers. What exists points to booking by WhatsApp or phone directly. Booking apps are just emerging (مناسبات يمنية). Peak seasons are the Eids and holidays.

### Cited Findings
- The «مناسبات يمنية» site and app let you "send a booking request for your event date" to providers. The app is on Google Play and the App Store, and the site covers halls, koshas, منشدين, DJs, photography, coordinators, cakes and lighting — [مناسبات يمنية](https://monasabatyemeniah.com/services/koshah). Note: the site's contact number has a French prefix (+33), which suggests it is run from the diaspora.
- The busiest seasons for henna painting (and weddings) are "the Eids and holidays", with henna prices around **20,000 YER** depending on type and amount — [يمن شباب نت](https://yemen-shabab.com/reports/61958) (search snippet only; when fetched, the link redirected to an unrelated suspicious domain, so it could not be verified; old date).
- In Houthi-controlled areas, hall owners raise their rents to cover levies "in the name of supporting the war effort" — [المشاهد نت 2021](https://almushahid.net/75127/)
- Women photographers' and coordinators' TikTok pages carry WhatsApp numbers for booking — [TikTok: منسقة أعراس عدن](https://www.tiktok.com/discover/%D8%A7%D9%85-%D8%B9%D9%84%D9%8A-%D9%85%D9%86%D8%B3%D9%82%D8%A9-%D8%A7%D8%B9%D8%B1%D8%A7%D8%B3-%D8%B9%D8%AF%D9%86-%D8%A7%D9%81%D8%B1%D8%A7%D8%AD-%D8%A7%D9%84%D8%B4%D8%B9%D9%8A%D8%A8%D9%8A); the Facebook page of Taiz photographer Eman al-Rifai (رقم تواصل + Instagram) — [Facebook](https://www.facebook.com/em2n0reefae7/)

### Inferences
- Probable norms (**unconfirmed**): a deposit (عربون) in cash or by money transfer (كريمي / remittance networks) to hold the date. A verbal agreement or a WhatsApp message instead of a formal contract. The deposit is often not refunded on cancellation. The app should support recording a deposit, the deposit's status, and an optional cancellation policy for each provider.
- Peak seasons are probably: after Eid al-Fitr, after Eid al-Adha, and summer holidays. Weddings tend to drop during Ramadan. Thursday is the preferred day in Sana'a (cited above), so Thursday will be the main pressure point for double booking.

### Gaps
- No sources found on lead times (how many months ahead), deposit percentages, or written contracts.

## 4. Pricing

### Takeaway
Very little published pricing data, and it varies widely by area and currency (old YER in Sana'a vs new YER in Aden, plus dollar and Saudi riyal pricing). The available listings show both a single fixed price and a range.

### Cited Findings
- A kosha from an event office in Sana'a (al-Wahda district) priced at **2,380,000 YER** — [مناسبات يمنية](https://monasabatyemeniah.com/services/koshah) (listing images uploaded in 2026).
- A home kosha at **10,000 YER**, with free installation — [Yemen Mazad](https://yemenmazad.com/products/%D9%83%D9%88%D8%B4-301625) (date unknown).
- Older, undated Sana'a hall prices: one hall at about 300,000 for 200–500 people, another at about $1,800 — [أوزان](https://ozan.fun/%D8%A7%D8%B3%D8%B9%D8%A7%D8%B1-%D8%A7%D9%84%D9%82%D8%A7%D8%B9%D8%A7%D8%AA) (low reliability).
- Henna painting at about 20,000 YER (see the caveat in section 3) — [يمن شباب نت](https://yemen-shabab.com/reports/61958)
- A Houthi rule in Hamdan directorate (Oct 2024) set fines of up to 500,000 YER (about $900) for violations at women's weddings — [النداء](https://www.alndaa.net/posts/100603). This shows the scale of costs and risk a host faces.

### Inferences
- The pricing model should support: a fixed price per period, a package with items (photos / video / album / drone / مصورة), a "starts from" price, a currency field (old YER, new YER, SAR, USD), and a travel fee to another governorate.
- Because of the split between the two YER currencies in the north and south, the currency must be explicit on every price.

### Gaps
- No published prices found for الفنان، المنشد، البرع، المزمار، المصورة، الكوافير or الألعاب النارية. These need field work or a survey of WhatsApp pages and statuses.

## 5. Women-only providers: privacy and marketing

### Takeaway
Women's privacy is the most serious concern. Leaked video from a women's party has led to violence. Some local authorities ban photographing the bride entirely, and photo-based blackmail is widespread with weak legal protection. Women photographers exist and market on TikTok and Facebook, often showing their work without their faces.

### Cited Findings
- A video leaked from a women's party in Sana'a (filmed by a woman, copied by her husband and posted to TikTok) reportedly led to armed clashes with deaths and injuries — [العربي نيوز](https://al-arabinews.com/amp2545.html) (based on activists' accounts; not officially confirmed; undated).
- A report said a woman in Sana'a was arrested for filming women's weddings and selling or publishing the footage, along with calls for female security at women's parties — [الأوراق برس](https://www.awraqpress.net/portal/news-3354.htm) (search snippet only; the site is suspended, undated).
- The Hamdan directorate rule (Sana'a governorate, about Oct 2024): no singing or celebration in women's halls, **no photographing the bride in any form**, the party ends by 9 pm, no loudspeakers and no open windows, the groom may not enter, fines up to 500,000 YER — [النداء](https://www.alndaa.net/posts/100603)
- Photo-based blackmail of Yemeni women; activists count 6 suicides. Yemeni law does not treat electronic blackmail as a specific crime — [الجزيرة نت 2022](https://www.aljazeera.net/women/2022/11/16/%D9%87%D8%B1%D9%88%D8%A8%D8%A7%D9%8B-%D9%85%D9%86-%D9%82%D8%B3%D9%88%D8%A9-%D8%A7%D9%84%D9%85%D8%AC%D8%AA%D9%85%D8%B9-%D8%A7%D8%A8%D8%AA%D8%B2%D8%A7%D8%B2); [نسوان فويس](https://neswanvoice.com/?p=9499); [Arab Reform Initiative](https://www.arab-reform.net/publication/cybercrime-against-women-in-yemen-legal-frameworks-and-social-change/)
- Yemeni photographer Eman Tuhamah: her family first rejected her work. After harassment in the street she moved to photographing **women's weddings**, festivals and events. She built her business through contacts and acquaintances — [The New Arab, 9 Apr 2018](https://www.newarab.com/analysis/yemeni-women-photographers-strive-overcome-barriers)
- Women photographers and coordinators in Aden are active on TikTok (#مصورات_عدن, «امتنان عيسى», the coordinator «أم علي») — [TikTok discover](https://www.tiktok.com/discover/%D8%A7%D9%85-%D8%B9%D9%84%D9%8A-%D9%85%D9%86%D8%B3%D9%82%D8%A9-%D8%A7%D8%B9%D8%B1%D8%A7%D8%B3-%D8%B9%D8%AF%D9%86-%D8%A7%D9%81%D8%B1%D8%A7%D8%AD-%D8%A7%D9%84%D8%B4%D8%B9%D9%8A%D8%A8%D9%8A) (discovery page; names not verified).
- The traditional "مزينة/مقينة" role (preparing the bride, henna, jewelry) was documented as a women-only trade in the region. That source is Saudi (Hejaz), not Yemeni — [Saudipedia](https://saudipedia.com/%D9%85%D9%87%D9%86%D8%A9-%D8%A7%D9%84%D9%85%D9%82%D9%8A%D9%86%D8%A9)

### Inferences
- Privacy requirements for the app (**design recommendations based on the evidence above**):
  - The provider can hide her phone number, with contact routed through the app or through a designated relative (محرم).
  - A portfolio without faces (decor, hands, dresses), with blurring.
  - Booking for a women's event is visible only to women's accounts or to the bride's family.
  - A "no photography of the bride" option on each event, and a "no publishing" commitment from the photographer.
  - No commercial registration required for individual providers. Verify identity by other means instead (ID, references).
- Rules differ by area (Houthi-controlled vs government-controlled). The app may need regional settings that warn about local restrictions (end times, bans on music) without enforcing them.

### Gaps
- No sources found on how women photographers write privacy into agreements (handing over all copies, deleting files), or on communicating through relatives.

## 6. Marketing channels and example vendors

### Takeaway
TikTok and Facebook dominate, with WhatsApp numbers for booking. Instagram is secondary. Directory sites and apps are starting to appear (مناسبات يمنية، حلم العاصمة).

### Cited Findings
- **Taiz:** المصورة إيمان الرفاعي, "photography of all occasions, video and stills", Facebook + Instagram — [Facebook](https://www.facebook.com/em2n0reefae7/)
- **Sana'a koshas:** «أرجوان لكوش الأعراس», Sanaani heritage-style koshas, design and management of wedding parties — [Facebook](https://www.facebook.com/argwan090/); «الذوق الرفيع», custom koshas — [Canva site](https://the-happy-yemen.my.canva.site/dafkynl1dw4); «كوش هيڤن» (الدائري) — [مناسبات يمنية](https://monasabatyemeniah.com/services/koshah)
- **Sana'a fireworks:** «القملي للألعاب النارية لمستلزمات الأعراس والأفراح» — [Facebook](https://www.facebook.com/Mohammed772526510/)
- **Sana'a henna:** TikTok pages tagged «احسن منقشه حناء في صنعاء» — [TikTok](https://www.tiktok.com/discover/%D8%A7%D8%AD%D8%B3%D9%86-%D9%85%D9%86%D9%82%D8%B4%D9%87-%D8%AD%D9%86%D8%A7%D8%A1-%D9%81%D9%8A-%D8%B5%D9%86%D8%B9%D8%A7%D8%A1?lang=en)
- **Aden:** women photographers and coordinators on TikTok — [TikTok](https://www.tiktok.com/discover/%D9%85%D9%86%D8%B3%D9%82%D9%87-%D8%A7%D8%B9%D8%B1%D8%A7%D8%B3-%D9%81%D9%8A-%D8%B9%D8%AF%D9%86)
- **Singers:** singer Aseel Abu Baker posts on Facebook, and was abducted from a Sana'a wedding hall in 2021 — [Arab News, 1 Sep 2021](https://www.arabnews.com/node/1921131/middle-east)

### Inferences
- The app should import or link TikTok, Facebook and Instagram accounts as a portfolio, and offer a "contact on WhatsApp" button (or an alternative button for providers who hide their number).

### Gaps
- No documented example vendors found in Hadramout (Mukalla / Seiyun). Voice notes as a marketing channel are not documented. YouTube was not covered.

## 7. Legal and security context for singers, music and fireworks

### Takeaway
In Houthi-controlled areas, singers and musicians face bans, raids and arrests at weddings. Local rules vary by directorate. In government-controlled areas (Aden, Qa'taba), the restrictions target celebratory gunfire, not music. This directly affects "no-show" risk and cancellations caused by forces outside the provider's control.

### Cited Findings
- Directives barred singers and musicians from performing at weddings in Sana'a, allowing only loyalist منشدين and زوامل performers — [صدى الساحل](https://www.sada-alsahel.net/news/180381)
- Arrests of dozens of singers, sound engineers and hall owners in Amran — [درج](https://daraj.media/%D8%A7%D9%84%D8%A5%D9%85%D8%A7%D9%85%D8%A9-%D9%88%D8%A7%D9%84%D8%AD%D9%88%D8%AB%D9%8A%D9%91%D8%A9-%D8%AC%D8%B0%D9%88%D8%B1-%D8%A7%D9%84%D8%AA%D8%AD%D8%B1%D9%8A%D9%85-%D8%A7%D9%84%D8%AF%D9%8A/); a ban on music at weddings in Hajjah (2018) — [منشور برس](https://manshur.net/archives/738)
- Singer Aseel Abu Baker was abducted around 2 am from a Sana'a wedding hall and his oud was confiscated (2021). He had escaped a similar raid in Amran in 2019. Singer Fuad al-Kibsi was held for 8 hours at a checkpoint in Hodeidah — [Arab News 2021](https://www.arabnews.com/node/1921131/middle-east)
- Houthi supervisors bring زوامل performers and preachers to weddings without the hosts' consent, and fine those who refuse (including over gunfire during fireworks) — [المشاهد نت 2021](https://almushahid.net/75127/)
- Aden: the security committee approved confiscating weapons, arresting offenders and a fine of 1,000,000 YER for celebratory gunfire at weddings — [المشهد اليمني](https://www.almashhad.news/news/500905)
- Qa'taba: a ban on gunfire at weddings, with one month in prison and a 500,000 YER fine — [pressbee](https://arabic.pressbee.net/show11054652.html)
- Fireworks set off inside a hall hosting a women's wedding in Sana'a caused panic — [صوت الشورى](https://sawtalshoura.com/uncategorized/%D8%A5%D8%B7%D9%84%D8%A7%D9%82-%D8%A3%D9%84%D8%B9%D8%A7%D8%A8-%D9%86%D8%A7%D8%B1%D9%8A%D8%A9-%D9%81%D9%8A-%D8%B5%D8%A7%D9%84%D8%A9-%D9%8A%D9%82%D8%A7%D9%85-%D9%81%D9%8A%D9%87%D8%A7-%D8%B9%D8%B1%D8%B3/); 4 children injured by fireworks in Aden — [يمن ناو](https://yemennownews.com/article/3286051)

### Inferences
- Add a cancellation reason such as "force majeure / regulatory restriction", separate from a provider no-show, so ratings are not unfairly hurt.
- Fireworks are better modeled as a product (retail sale) than a booked service, with safety warnings.

### Gaps
- The current status of the restrictions (2025–2026) is not confirmed. Most sources date from 2018–2024, and some are politically hostile to the Houthis.

## 8. Common disputes

### Takeaway
The best-documented dispute is leaked photos from women's events, which carries serious consequences. Other disputes (no-shows, late arrival, photo delivery delays, double booking) are probable, but this research found no published source documenting them.

### Cited Findings
- Leaked women's-party video → armed clashes (reported) — [العربي نيوز](https://al-arabinews.com/amp2545.html)
- Photo-based blackmail and its consequences — [الجزيرة نت 2022](https://www.aljazeera.net/women/2022/11/16/%D9%87%D8%B1%D9%88%D8%A8%D8%A7%D9%8B-%D9%85%D9%86-%D9%82%D8%B3%D9%88%D8%A9-%D8%A7%D9%84%D9%85%D8%AC%D8%AA%D9%85%D8%B9-%D8%A7%D8%A8%D8%AA%D8%B2%D8%A7%D8%B2)
- A singer missing a wedding because of a raid or arrest is a real risk — [Arab News 2021](https://www.arabnews.com/node/1921131/middle-east)

### Inferences
- The app should include: a delivery date for photos and video with reminders, a check-in/arrival time log, a check that blocks overlapping bookings against capacity, and a confidentiality pledge for photographers at women's events.

### Gaps
- No complaints forums or consumer reports found on Yemeni photographers' delivery delays or double booking. Mining Facebook comments or interviews is recommended.
