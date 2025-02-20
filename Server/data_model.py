from pymongo import MongoClient
from datetime import datetime

# client = MongoClient('mongodb://localhost:27017/')
# db = client.evaDB

class DataModel:
    def __init__(self, date=None, src_img_name=None, src_img_path=None, tgt_img_path=None,cs=None,va=None):
        self.date = date if date else datetime.now()
        self.src_img_name = src_img_name
        self.src_img_path = src_img_path
        self.tgt_img_path = tgt_img_path
        self.cs = cs
        self.va = va

    def to_dict(self):
        return {
            "date": self.date,
            "src_img_name": self.src_img_name,
            "src_img_path": self.src_img_path,
            "tgt_img_path": self.tgt_img_path,
            "cs": self.cs,
            "va": self.va
        }

# data_collection = db.data
