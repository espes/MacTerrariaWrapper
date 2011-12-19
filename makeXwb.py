import struct
import os

def main(outFileName, wmas, name="Wave Bank"):
   
   with open(outFileName, "wb") as outFile:
      outFile.write("WBND")
      outFile.write(struct.pack("II",
         46, #major version
         44 #minor version
      ))
      
      bankData = struct.pack("II64sIIIIII", 
         0, #flags 
         len(wmas),
         name,
         24, #entry meta data size
         64, #entry name size
         0, #alignment
         0, #format data for compact format
         0, #unkn?
         0, #unkn?
      )
      
      metaDatas = []
      playRegionCur = 0
      for wma in wmas:
         codec = 3
         chans = 2
         rate = 44100
         align = 99
         bits = 0
         
         format = (
            (codec & 0b11) |
            ((chans & 0b111) << 2) |
            ((rate & 0x3ffff) << (2+3)) |
            ((align & 0xff) << (2+3+18)) |
            ((bits & 1) << (2+3+18+8))
         )
         
         playDataSize = os.path.getsize(wma)
         
         metaData = struct.pack("IIIIII",
            0, #flags and duration...?
            format,
            playRegionCur, #play region offset
            playDataSize, #play region length
            0, #loop region offset
            0  #loop region length
         )
         metaDatas.append(metaData)
         playRegionCur += playDataSize
      
      metaDatas = ''.join(metaDatas)
      
      seekTable = ""
      unknRegion = ""
      
      headerFormat = "IIIIIIIIII"
      headerEndOffset = outFile.tell()+struct.calcsize(headerFormat)
      outFile.write(struct.pack(headerFormat,
         headerEndOffset, #bank data offset
         len(bankData), #bank data len
         
         headerEndOffset+len(bankData), #entry metadata offset
         len(metaDatas), #entry metadata len
         
         headerEndOffset+len(bankData)+len(metaDatas), #seek table offset
         len(seekTable), #seek table len
         
         headerEndOffset+len(bankData)+len(metaDatas)+len(seekTable), #unkn region offset
         len(unknRegion),
         
         headerEndOffset+len(bankData)+len(metaDatas)+len(seekTable)+len(unknRegion), #play region offset
         playRegionCur
      ))
      
      assert outFile.tell() == headerEndOffset
      
      outFile.write(bankData)
      outFile.write(metaDatas)
      outFile.write(seekTable)
      outFile.write(unknRegion)
      
      for wma in wmas:
         outFile.write(open(wma, "rb").read())


if __name__ == "__main__":
   from sys import argv
   main(argv[1], argv[2:])