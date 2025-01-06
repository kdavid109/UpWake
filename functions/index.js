const { onObjectFinalized } = require('firebase-functions/v2/storage');
const admin = require('firebase-admin');
const fetch = require('node-fetch');
const FormData = require('form-data');

admin.initializeApp();

// Helper function to wait
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// Helper function to check file existence with retries
async function checkFileExists(file, maxRetries = 3, delayMs = 2000) {
    for (let i = 0; i < maxRetries; i++) {
        console.log(`Checking file existence attempt ${i + 1}/${maxRetries}`);
        const [exists] = await file.exists();
        if (exists) {
            return true;
        }
        if (i < maxRetries - 1) {
            console.log(`File not found, waiting ${delayMs}ms before retry...`);
            await delay(delayMs);
        }
    }
    return false;
}

exports.processImage = onObjectFinalized({
    timeoutSeconds: 540,  // 9 minutes
    memory: '2GB',
    retry: true
}, async (event) => {
    console.log('Processing new image upload:', event.data.name);
    
    // Only process objects in the 'objects' folder
    if (!event.data.name.startsWith('users/') || !event.data.name.includes('/objects/')) {
        console.log('Not an object image, skipping processing');
        return null;
    }

    const filePath = event.data.name;
    const bucket = admin.storage().bucket(event.bucket);
    const file = bucket.file(filePath);

    try {
        // Check if file exists with retries
        console.log(`Checking existence of file: ${filePath}`);
        const exists = await checkFileExists(file);
        if (!exists) {
            console.error(`File ${filePath} does not exist after retries`);
            return null;
        }

        // Get metadata to ensure it's an image
        console.log('Getting file metadata');
        const [metadata] = await file.getMetadata();
        if (!metadata.contentType || !metadata.contentType.startsWith('image/')) {
            console.error(`File ${filePath} is not an image (${metadata.contentType})`);
            return null;
        }

        // Initial delay to ensure file is fully available
        await delay(2000);

        // Get the download URL
        console.log('Generating signed URL');
        const [url] = await file.getSignedUrl({
            action: 'read',
            expires: Date.now() + 1000 * 60 * 60, // 1 hour
        });

        console.log('Generated signed URL for image');

        // Call remove.bg API
        const formData = new FormData();
        formData.append('image_url', url);
        formData.append('size', 'auto');
        formData.append('format', 'png');
        formData.append('type', 'auto');
        formData.append('bg_color', 'white');

        console.log('Calling remove.bg API');
        const response = await fetch('https://api.remove.bg/v1.0/removebg', {
            method: 'POST',
            headers: {
                'X-Api-Key': process.env.REMOVEBG_API_KEY
            },
            body: formData
        });

        if (!response.ok) {
            throw new Error(`Remove.bg API error: ${response.statusText}`);
        }

        const imageBuffer = await response.buffer();
        console.log('Successfully removed background from image');

        // Create a new filename for the processed image
        const processedFilePath = filePath.replace(/\.(jpg|jpeg|png)$/i, '_nobg.png');
        const processedFile = bucket.file(processedFilePath);

        // Upload the processed image
        console.log('Uploading processed image');
        await processedFile.save(imageBuffer, {
            metadata: {
                contentType: 'image/png',
                metadata: {
                    originalFile: filePath,
                    processedAt: new Date().toISOString()
                }
            }
        });

        // Get the download URL for the processed image
        const [processedUrl] = await processedFile.getSignedUrl({
            action: 'read',
            expires: Date.now() + 1000 * 60 * 60 * 24 * 365, // 1 year
        });

        // Get the Firestore document reference
        const userId = filePath.split('/')[1];
        const objectId = filePath.split('/').pop().split('.')[0]; // Remove file extension
        const docRef = admin.firestore()
            .collection('users').doc(userId)
            .collection('objects').doc(objectId);

        // Update Firestore document with processed image
        console.log('Updating Firestore document');
        await docRef.update({
            processedImageUrl: processedUrl,
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log(`Successfully processed image: ${filePath}`);
        console.log(`Processed image URL: ${processedUrl}`);

        return null;
    } catch (error) {
        console.error('Error processing image:', error);
        
        // Try to update Firestore with error state if possible
        try {
            const userId = filePath.split('/')[1];
            const objectId = filePath.split('/').pop().split('.')[0];
            const docRef = admin.firestore()
                .collection('users').doc(userId)
                .collection('objects').doc(objectId);
                
            await docRef.update({
                processed: false,
                processingError: error.message,
                processedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } catch (updateError) {
            console.error('Failed to update error state in Firestore:', updateError);
        }
        
        throw error;
    }
});
