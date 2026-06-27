import scrapy
from tutorial.items import QuoteItem

class QuotesSpider(scrapy.Spider):
    name = 'quotes'
    allowed_domains = ['quotes.toscrape.com']
    start_urls = ['http://quotes.toscrape.com/']

    def parse(self, response):
        quote_blocks = response.xpath('//div[@class="quote"]')
        for block in quote_blocks:
            item = QuoteItem()
            item['text'] = block.xpath('.//span[@class="text"]/text()').get()
            item['author'] = block.xpath('.//small[@class="author"]/text()').get()
            item['tags'] = block.xpath('.//div[@class="tags"]//a/text()').getall()
            yield item

        next_page = response.xpath('//li[@class="next"]/a/@href').get()
        if next_page:
            next_url = response.urljoin(next_page)
            yield scrapy.Request(next_url, callback=self.parse)
