class QuotesPipeline:
    def process_item(self, item, spider):
        if item.get('text'):
            item['text'] = item['text'].replace('“', '').replace('”', '')
        return item