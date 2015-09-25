module Fog
  module Storage
    class Aliyun
      class Real
        # Put details for object
        #
        # ==== Parameters
        # * container<~String> - Name of container to look in
        # * object<~String> - Name of object to look for
        #
        def put_object(object, file=nil, options={})

          bucket = options[:bucket]
          bucket ||= @aliyun_oss_bucket
          location = get_bucket_location(bucket)
          endpoint = "http://"+location+".aliyuncs.com"
          if (nil == file)
            return put_folder(bucket, object, endpoint)
          end
          
          #object size 超过100M，走分片上传，支持断点续传
          if file.size >104857600
            return put_multipart_object(bucket, object, file)
          end
          
          body = file.read
          
          resource = bucket+'/'+object
          ret = request(
                  :expects  => [200, 203],
                  :method   => 'PUT',
                  :path     => object,
                  :bucket   => bucket,
                  :resource => resource,
                  :body => body,
                  :endpoint => endpoint
          )
        
        end

        def put_object_with_body(object, body, options={})

          bucket = options[:bucket]
          bucket ||= @aliyun_oss_bucket
          location = get_bucket_location(bucket)
          endpoint = "http://"+location+".aliyuncs.com"
          
          #object size 超过100M，走分片上传，支持断点续传
#          if body.size >104857600
#            put_multipart_object_with_body(bucket, object, body)
#            return
#          end
                    
          resource = bucket+'/'+object
          ret = request(
                  :expects  => [200, 203],
                  :method   => 'PUT',
                  :path     => object,
                  :bucket   => bucket,
                  :resource => resource,
                  :body => body,
                  :endpoint => endpoint
          )
        
      end
      
        def put_folder(bucket, folder, endpoint)
          if (nil == endpoint)
            location = get_bucket_location(bucket)
            endpoint = "http://"+location+".aliyuncs.com"
          end
          path = folder+'/'
          resource = bucket+'/'+folder+'/'
          ret = request(
                  :expects  => [200, 203],
                  :method   => 'PUT',
                  :path     => path,
                  :bucket   => bucket,
                  :resource => resource,
                  :endpoint => endpoint
          )
        end
        
        def put_multipart_object(bucket, object, file)

          location = get_bucket_location(bucket)
          endpoint = "http://"+location+".aliyuncs.com"
          
          #遍历bucket下uploads事件，找到对应upload，则继续，否则创建upload事件
          uploads = list_multipart_uploads(bucket, endpoint)
          if nil != uploads
	    upload = uploads.find do |tmpupload| tmpupload["Key"][0] == object end
          else
            upload = nil
          end
          
          parts = nil
          uploadedSize = 0
          start_partNumber = 1
          if ( nil != upload )
            uploadId = upload["UploadId"][0]
            parts = list_parts(bucket, object, endpoint, uploadId)
            if ((nil != parts) &&(0 != parts.size))
              if (parts[-1]["Size"][0].to_i != 5242880)
                #上传最后一片不是正常的5M,说明已经上传完毕，结束上传
                complete_multipart_upload(bucket, object, endpoint, uploadId)
                return
              end
              uploadedSize = (parts[0]["Size"][0].to_i * (parts.size - 1)) + parts[-1]["Size"][0].to_i
              start_partNumber = parts[-1]["PartNumber"][0].to_i + 1
            end
          else
            #InitiateMultipartUpload获取Upload ID
            uploadId = initiate_multipart_upload(bucket, object, endpoint)
          end
          
          if (file.size <= uploadedSize)
            #文件大小小于或等于已上传量,说明已经上传完毕，结束上传
            complete_multipart_upload(bucket, object, endpoint, uploadId)
            return
          end
          
          end_partNumber = (file.size + 5242880 -1) / 5242880
          file.seek(uploadedSize)
          
          for i in start_partNumber..end_partNumber
            body = file.read(5242880)
            upload_part(bucket, object, endpoint, i.to_s, uploadId, body)
          end
          
          complete_multipart_upload(bucket, object, endpoint, uploadId)
        end
        
        def initiate_multipart_upload(bucket, object, endpoint)
          if (nil == endpoint)
            location = get_bucket_location(bucket)
            endpoint = "http://"+location+".aliyuncs.com"
          end
          path = object+"?uploads"
          resource = bucket+'/'+path
          ret = request(
                  :expects  => 200,
                  :method   => 'POST',
                  :path     => path,
                  :bucket   => bucket,
                  :resource => resource,
                  :endpoint => endpoint
          )
          uploadid = XmlSimple.xml_in(ret.data[:body])["UploadId"][0]
        end
        
        def upload_part(bucket, object, endpoint, partNumber, uploadId, body)
          if (nil == endpoint)
            location = get_bucket_location(bucket)
            endpoint = "http://"+location+".aliyuncs.com"
          end
          path = object+"?partNumber="+partNumber+"&uploadId="+uploadId
          resource = bucket+'/'+path
          ret = request(
                  :expects  => [200, 203],
                  :method   => 'PUT',
                  :path     => path,
                  :bucket   => bucket,
                  :resource => resource,
                  :body => body,
                  :endpoint => endpoint
          )
        end
        
        def complete_multipart_upload(bucket, object, endpoint, uploadId)
          if (nil == endpoint)
            location = get_bucket_location(bucket)
            endpoint = "http://"+location+".aliyuncs.com"
          end
          parts = list_parts(bucket, object, endpoint, uploadId, options = {})
          request_part = Array.new
          if parts.size == 0
            return
          end
          for i in 0..(parts.size-1)
            part = parts[i]
            request_part[i] = {"PartNumber"=>part["PartNumber"], "ETag"=>part["ETag"]}
          end
          body = XmlSimple.xml_out({"Part"=>request_part},'RootName'=>'CompleteMultipartUpload')

          path = object+"?uploadId="+uploadId
          resource = bucket+'/'+path
          ret = request(
                  :expects  => 200,
                  :method   => 'POST',
                  :path     => path,
                  :bucket   => bucket,
                  :resource => resource,
                  :endpoint => endpoint,
                  :body => body
          )
          
        end
      end
      
      class Mock
        def put_object(object, file=nil, options={})

        end
      end
    end
  end
end
