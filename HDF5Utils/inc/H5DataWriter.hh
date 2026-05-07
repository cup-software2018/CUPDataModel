#pragma once

#include <string>

// AbsH5Base covers both AbsH5Event and AbsH5Hit
#include "AbsH5Base.hh"

class H5DataWriter {
public:
  H5DataWriter();
  H5DataWriter(const char * fname, int compress = 1);
  ~H5DataWriter();

  bool Open();
  void Close();

  void SetFilename(const char * name);
  void SetCompressionLevel(int level);

  // Changed from SetEvent(AbsH5Event*) to support both Event and Hit datas
  void SetData(AbsH5Base * data);
  void SetSubrun(int sub);

  hid_t GetFileId() const;
  hsize_t GetFileSize() const;
  hsize_t GetMemorySize() const;

  AbsH5Base * GetData();
  const char * GetFilename() const;
  bool IsOpen() const;

  void PrintStats() const;

private:
  std::string fFilename;

  hid_t fFileId;
  int fCompressionLevel;

  // Unified pointer to handle H5FADCEvent, H5SADCEvent, H5FADCHit, H5SADCHit
  AbsH5Base * fData;

  hsize_t fFileSize;
  hsize_t fMemorySize;
  int fSubrun;
};

inline void H5DataWriter::SetFilename(const char * fname) { fFilename = fname ? fname : ""; }

inline void H5DataWriter::SetCompressionLevel(int level) { fCompressionLevel = level; }

inline void H5DataWriter::SetData(AbsH5Base * data) { fData = data; }

inline void H5DataWriter::SetSubrun(int sub) { fSubrun = sub; }

inline hid_t H5DataWriter::GetFileId() const { return fFileId; }

inline hsize_t H5DataWriter::GetFileSize() const
{
  hsize_t size = 0;
  if (fFileId >= 0) { H5Fget_filesize(fFileId, &size); }
  return size;
}

inline hsize_t H5DataWriter::GetMemorySize() const { return fData ? fData->GetSize() : 0; }

inline AbsH5Base * H5DataWriter::GetData() { return fData; }

inline const char * H5DataWriter::GetFilename() const { return fFilename.c_str(); }

inline bool H5DataWriter::IsOpen() const { return fFileId >= 0; }