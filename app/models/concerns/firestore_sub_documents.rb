module FirestoreSubDocuments

  ##
  # FirestoreSubDocuments: Module that adds sub-collection and sub-document functionality to FirestoreDocuments
  ##

  extend ActiveSupport::Concern

  included do

    def sub_documents
      self.reference.col(self.class.sub_collection_name)
    end

    # return all sub-documents for a parent as a Hash, using one array as key names, and the other as values
    def sub_documents_as_hash(keys_name, values_name)
      document_data = {}
      self.sub_documents.get.each do |sub_document|
        doc_data = sub_document.data
        document_data.merge!(Hash[doc_data[keys_name.to_sym].zip(doc_data[values_name.to_sym])])
      end
      document_data
    end
  end
end
