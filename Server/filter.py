## Horizontal and Vertical Shift of Contrast Sensitivity Function
# HShiftList is horizontal shift. The smaller the ratio is, the more blurry the image would be.
# VShiftList is vertical shift. The smaller the ratio is, the more low contrast the image would be. 
# Refer to Xiong et al., 2021 Fontiers in Neuroscience Table for corresponding acuity (logMAR) and contrast sensitivity (logCS) levels


import cv2
import math
import numpy as np
# import matplotlib.pyplot as plt
import os
from tqdm import tqdm
from copy import deepcopy
import glob
import re
import io
from PIL import Image
import pyheif   ## need to update libheif first ->  brew install libheif
import rawpy
import imageio

## iPhone 15 pro max: 6.7 inch, 2796 x 1290 pixels, 460 ppi
## iPhone 15 pro : 6.1 inch, 2556 x 1179 pixels, 460 ppi
def add_filter(img,HShift,VShift,reso = (2796,1290), screen_size = 13.3, camera = True, white_balance=False, ppi=None):
    charIm = deepcopy(img)
    thisHShift = HShift
    thisVShift = VShift
    v,h,c = charIm.shape
    # if image not taken by a camera therefore viewing angle depend on the viewing distance
    if not camera:
        # Calculate Viewing Angle
        # PPI = sqrt((horizontal reso/width in inches)^2 + (vertical reso/height in inches)^2)
        # PPcm = PPI/2.54
        PPI = np.sqrt(reso[0]**2 + reso[1]**2)/screen_size
        ppcm = PPI/2.54
        PsysicalWidth = charIm.shape[0]/ppcm # physical width/height of the image on the screen (cm)
        PsysicalHeight = charIm.shape[1]/ppcm # physical width/height of the image on the screen (cm)
        distance=40 # Viewing distance in cm
        vh = 2*math.atan((PsysicalWidth)/(2*distance))*(180/math.pi) #horizontal visual angle of the image at the specified viewing distance
        vv = 2*math.atan((PsysicalHeight)/(2*distance))*(180/math.pi) #vertival visual angle of the image at the specified viewing distance
        imgSize = vh*vv #visual angle of the entire image at the specified viewing distance

        #% hsize=PsysicalWidth/h; % height of a pixel in cm (cm/pixel)
        #% vsize=PsysicalHeight/v; % width of a pixel in cm (cm/pixel)
    else:
        if v > h:
            vv = 71
            vh = 56
        else:  
            vh = 71 # iPhone main camera horizontal field of view in degrees
            vv = 56 # iPhone main camera vertical field of view in degrees
        imgSize = vh*vv # visual angle of the entire image 
        
    h=charIm.shape[1] # horizontal pixel number of the image
    v=charIm.shape[0] # vertical pixel number of the image
    fx = np.arange(start=-h/2, stop=h/2, step=1)
    fx = fx/vh
    fy = np.arange(start=-v/2, stop=v/2, step=1)
    fy = fy/vv
    [ux,uy] = np.meshgrid(fx,fy)
    finalImg = np.zeros_like(charIm)
    for j in range(3): # three color channels or only luminance channel
        
        thisimage = charIm[:,:,j].astype(np.float64)
        meanLum = np.mean(thisimage)
        ## Generate blur
        
        

        ## Horizontal shift
        sSF0 = np.sqrt(ux**2+uy**2+.0001)
        CSF0 = (5200*np.exp(-.0016* (100/meanLum+1)**.08 * sSF0**2))/np.sqrt((0.64*sSF0**2+144/imgSize+1) * (1./(1-np.exp(-.02*sSF0**2))+63/(meanLum**.83)))
        sSF = thisHShift*np.sqrt(ux**2+uy**2+.0001)
        if white_balance:
            # Vertical Shift
            for ii in range(thisimage.shape[0]):
                for jj in range(thisimage.shape[1]):
                    if thisimage[ii,jj] !=255:
                        thisimage[ii,jj] = np.round(255-np.round((255-thisimage[ii,jj])*thisVShift))
            CSF = (5200*np.exp(-.0016*(100/meanLum+1)**.08*sSF**2))/np.sqrt((0.64*sSF**2+144/imgSize+1) * (1./(1-np.exp(-.02*sSF**2))+63/(meanLum**.83)))
        else:
            CSF = thisVShift*(5200*np.exp(-.0016*(100/meanLum+1)**.08*sSF**2))/np.sqrt((0.64*sSF**2+144/imgSize+1) * (1./(1-np.exp(-.02*sSF**2))+63/(meanLum**.83)))

        nCSF = np.fft.fftshift(CSF/CSF0)
        maxValue = 1
        nCSF = np.clip(nCSF,None,maxValue) #replace maximun to 1
        nCSF[0,0]=1
        
        Y = np.fft.fft2(thisimage)

        # spectrum = np.abs(Y)

        filtImg = np.real(np.fft.ifft2(nCSF*Y))
        
        ## put the three channels together
        finalImg[:,:,j] = np.clip(np.round(filtImg),0,255)
        
    
    return finalImg

def remove_dots_except_last(filename):
    parts = filename.split('.')
    # Join all parts except the last one with no dots
    new_filename = '_'.join(parts[:-1]) + '.' + parts[-1]
    return new_filename

def save_as_heic(image, output_path):
    # Create a HEIF image
    heif_file = pyheif.fromarray(image, mode="RGB")
    # Save the HEIF image
    with open(output_path, 'wb') as f:
        heif_file.save(f)



def add_filter_to_folder(imgStream,expFolder,imgName, a:float, b:float, camera_flag = True, white_flag = False,src_file=None):
    """_summary_

    Args:
        imgFolder (str): imgFolder is the directory where the input images are stored or the single input image.
        expFolder (str): expFolder is the directory where the output images will be saved.
        HShiftList (list): HShiftList is horizontal shift. The smaller the ratio is, the more blurry the image would be.
        VShiftList (list): VShiftList is vertical shift. The smaller the ratio is, the more low contrast the image would be. 
        filters (list, optional): filters used to add specific low vision effects to the input image. Defaults to [1].
        camera_flag (bool, optional): Flag to whether use iPhone Wide Camera or not. Defaults to True.
        white_flag (bool, optional): If set white as mean lum. Defaults to False.
    """
    # heif_file = pyheif.read_heif(imgStream)
    # src_image = Image.frombytes(
    #     heif_file.mode, 
    #     heif_file.size, 
    #     heif_file.data,
    #     "raw",
    #     heif_file.mode,
    #     heif_file.stride,
    #     ).convert('RGB')
    name,post = re.split(r'\.', imgName)
    inputImg = os.path.join(expFolder,name,imgName)
    outputImg = os.path.join(expFolder,name,f'{name}_{a}_{b}.png')
    outputImg = remove_dots_except_last(outputImg) # xxx0.002_0.003.png -> xxx0_002_0_003.png
    
    os.makedirs(os.path.dirname(outputImg), exist_ok=True)
    if post.lower().strip() == 'dng':
        # src_file.save(inputImg)
        # with rawpy.imread(inputImg) as raw:
        #     src_image = raw.postprocess(se_camera_wb=True)
        src_image = np.array(rawpy.imread(io.BytesIO(imgStream)).postprocess(), dtype=np.uint8)

    else:
        src_image = np.array(Image.open(io.BytesIO(imgStream)).convert('RGB'), dtype=np.uint8)
    
    
    
    
    
    ##TODO: Check a,b
    thisHShift = np.round(1/a,4)
    thisVShift = b 
    finalImg = add_filter(src_image,thisHShift,thisVShift,camera_flag,white_flag)
    ## Save Src and Filtered Images
    src_image = Image.fromarray(src_image)
    src_image.save(inputImg, format='PNG')
    # Image.fromarray(finalImg,'RGB').save(outputImg, format='PNG')
    # plt.imsave(outputImg,finalImg)
    
    # Convert the NumPy array to a PIL image
    image = Image.fromarray(finalImg)
    image.save(outputImg, format='PNG')
        
    # Save the image to a BytesIO object
    img_io = io.BytesIO()
    image.save(img_io, 'PNG')
    img_io.seek(0)

    
    # if post.lower().strip() == 'heic':
    #     save_as_heic(image, inputImg)
    # else:
    #     src_image.save(inputImg, format=post)


    
    mime_type = 'image/png'
        
    return (img_io,outputImg,mime_type)
            

if __name__ == '__main__':
    # HShiftList = [1.000, 0.288, 0.157, 0.086, 0.048, 0.027,
    #     0.250, 0.134, 0.072, 0.039, 0.022,
    #     0.267, 0.144, 0.078, 0.043, 0.024,
    #     0.314, 0.172, 0.096, 0.055, 0.032,
    #     0.345, 0.193, 0.110, 0.064, 0.038,
    #     0.439, 0.256, 0.154, 0.033, 0.018,
    #     0.125, 0.063, 0.031, 0.016, 1.000,
    #     1.000, 1.000, 1.000, 1.000, 1.000]

    # VShiftList = [1.000, 0.288, 0.157, 0.086, 0.048, 0.027,
    #     1.000, 0.534, 0.288, 0.157, 0.086,
    #     0.534, 0.288, 0.157, 0.086, 0.048,
    #     0.157, 0.086, 0.048, 0.027, 0.016,
    #     0.086, 0.048, 0.027, 0.016, 0.010,
    #     0.027, 0.016, 0.010, 0.534, 0.288,
    #     1.000, 1.000, 1.000, 1.000, 0.355,
    #     0.178, 0.089, 0.045, 0.022, 0.011]
    
    # HShiftList = [0.25, 0.125, 0.063, 0.031, 0.016,
    #           1, 1, 1, 1, 1, 1,
    #           0.267, 0.157, 0.086, 0.048, 0.022]
    # VShiftList = [1, 1, 1, 1, 1,
    #             0.355, 0.178, 0.089, 0.045, 0.022, 0.011,
    #             0.267, 0.157, 0.086, 0.048, 0.086]
    
    # filters=np.arange(1,len(HShiftList)+1)
    filters=[3]
    camera_flag = True
    white_flag = False
    
    imgFolder = 'imgs/IMG_5172.png' #'imgs/IMG_5172.png' # can be directory or single image file 
    expFolder = '/Users/kaiagao/Documents/Models/data/totaltext/selected_images_new/' # directory to save the output images
    
    # add_filter_to_folder(imgFolder,expFolder, HShiftList, VShiftList, filters, camera_flag = camera_flag, white_flag = white_flag)
  