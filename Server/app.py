from flask import Flask, request, jsonify, send_file
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure
from datetime import datetime
from data_model import DataModel
from bson import json_util
import json
from filter import add_filter_to_folder

import numpy as np
import io
from PIL import Image
import pandas as pd
import os

def parse_json(data):
    return json.loads(json_util.dumps(data))



def read_va_cs_matrix(path):
    mat = pd.read_csv(path).astype(float)
    return mat

def convert_ab(mat,va:float,cs:float):
    x = mat[(mat['VA'] == np.round(va,2)) & (mat['CS'] == np.round(cs,2)) ][['a','b']].values.reshape(-1).astype(float)
    a,b = x[0],x[1]
    return a,b
    
app = Flask(__name__)
client = MongoClient('mongodb://localhost:27017/')
db = client['evaDB']
data_collection = db['datas']
mat = read_va_cs_matrix('va_cs_matrix.csv')


# print(data_collection)
# for i in data_collection.find():
#     print(i)

# HShiftList = [1.000, 0.288, 0.157, 0.086, 0.048, 0.027,
#         0.250, 0.134, 0.072, 0.039, 0.022,
#         0.267, 0.144, 0.078, 0.043, 0.024,
#         0.314, 0.172, 0.096, 0.055, 0.032,
#         0.345, 0.193, 0.110, 0.064, 0.038,
#         0.439, 0.256, 0.154, 0.033, 0.018,
#         0.125, 0.063, 0.031, 0.016, 1.000,
#         1.000, 1.000, 1.000, 1.000, 1.000]

# VShiftList = [1.000, 0.288, 0.157, 0.086, 0.048, 0.027,
#         1.000, 0.534, 0.288, 0.157, 0.086,
#         0.534, 0.288, 0.157, 0.086, 0.048,
#         0.157, 0.086, 0.048, 0.027, 0.016,
#         0.086, 0.048, 0.027, 0.016, 0.010,
#         0.027, 0.016, 0.010, 0.534, 0.288,
#         1.000, 1.000, 1.000, 1.000, 0.355,
#         0.178, 0.089, 0.045, 0.022, 0.011]
expFolder = 'imgs/' # directory to save the output images
    

@app.route('/')
def home():
    return 'Hello World'

@app.route('/uploadImg', methods=['POST'])
async def upload_img():
    print("connected")
    print(request.files)
    print(request.form)
    # Access the uploaded file from the ImmutableMultiDict
    uploaded_file = request.files.get('src_img')
    cs = float(request.form.get('cs'))
    va = float(request.form.get('va'))
    
    if uploaded_file:
        src_img_name = uploaded_file.filename
        file_content = uploaded_file.read()
        ##TODO: Update imgFolder to the cloud path
        imgFolder = 'imgs/' ## directory to save the output images
        # file_name = os.path.join(imgFolder,src_img_name)
        # Do something with the file content, e.g., save it to disk
        # with open(file_name, 'wb') as f:
        #     f.write(file_content)
    # Convert the file to a NumPy array
    


    
    new_img = DataModel(src_img_name=src_img_name, src_img_path=imgFolder, cs=cs, va=va, date=datetime.now())
    a,b = convert_ab(mat,va,cs)

    filtered_img, tgt_path,mime_type = add_filter_to_folder(imgStream=file_content, a=a, b=b, camera_flag = True, white_flag = False,expFolder=imgFolder,imgName=src_img_name,src_file=uploaded_file)

    new_img.tgt_img_path = tgt_path
    tgt_name = tgt_path.split('/')[-1]
    result = data_collection.insert_one(new_img.to_dict())
    
    if result.acknowledged:
        return send_file(filtered_img, mimetype=mime_type, ## send the image as a response
                         as_attachment=False, ## send as an attachment to download/ Display
                         download_name=tgt_name, ## Name when saving the file
                         last_modified=datetime.now())
    else:
        return jsonify('Failed to save image')

@app.route('/update', methods=['POST'])
def update_img():
    filter_id = request.args.get('filterId')
    result = data_collection.update_one(
        {'filterId': filter_id},
        {'$set': {'filterId': '2'}}
    )
    # src_img = #request.files['srcImg']
    if result.modified_count > 0:
        return jsonify('Image Updated', 200)
    else:
        return jsonify('Failed to update image', 500)

@app.route('/photo', methods=['GET'])
def get_photo():
    db_items = data_collection.find() ## find all items in the collection
    items = [item for item in db_items]
    # for i in items:
        
    return jsonify(parse_json(items))

@app.route('/delete', methods=['POST'])
def delete_img():
    filter_id = request.args.get('filterId')
    result = data_collection.delete_one({'filterId': filter_id})
    if result.deleted_count > 0:
        return jsonify('Image deleted', status=200)
    else:
        return jsonify('Failed to delete image', 500)

if __name__ == '__main__':
    try:
        client.admin.command('ping')
        print('Connected to MongoDB')
    except ConnectionFailure:
        print('Failed to connect to MongoDB')
    app.run(host='0.0.0.0', port=5001,debug=True) #ipv4
# flask run --host=0.0.0.0 --port=5001