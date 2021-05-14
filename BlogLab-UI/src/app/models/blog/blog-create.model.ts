export class BlogCreate {

    constructor(
        public BlogId: number,
        public title: string,
        public content: string,
        public photoId?: number
    ) {}
    
}